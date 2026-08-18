import 'dart:convert';

import 'package:http/http.dart' as http;

// [09] 백엔드 서버 주소. Railway에 배포된 실제 URL을 기본값으로 쓴다.
// 로컬 백엔드로 다시 테스트하려면 빌드 시
// --dart-define=API_BASE_URL=http://10.0.2.2:3000 로 덮어쓴다.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://fearless-comfort-production-d70f.up.railway.app',
);

/// [07] /generate 호출이 실패했을 때 던지는 예외. 실패 사유(네트워크 오류,
/// 타임아웃, 서버 오류 등)와 무관하게 화면에는 항상 같은 안내 문구를 보여준다.
class AiRecordApiException implements Exception {
  const AiRecordApiException([this.message = '잠시 후 다시 시도해주세요']);

  final String message;

  @override
  String toString() => message;
}

/// [11] /generate 응답. 화면에 [상태]/[조치] 칸이 따로 있어서 백엔드가 둘을
/// 나눠 돌려준다 - 상태 관찰과 그에 따른 조치를 한 문단에 섞지 않기 위함.
class AiGeneratedRecord {
  const AiGeneratedRecord({required this.status, required this.action});

  final String status;
  final String action;
}

/// [07] 선택된 카테고리별 항목을 백엔드 /generate에 전달해 AI가 작성한
/// 상태/조치 문장을 받아온다.
class AiRecordApi {
  const AiRecordApi({this.baseUrl = kApiBaseUrl});

  final String baseUrl;

  Future<AiGeneratedRecord> generate(
    Map<String, List<String>> selections,
  ) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/generate'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object>{'selections': selections}),
          )
          .timeout(const Duration(seconds: 30));
    } on Object {
      throw const AiRecordApiException();
    }

    if (response.statusCode != 200) {
      throw const AiRecordApiException();
    }

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String status = decoded['status'] as String? ?? '';
      final String action = decoded['action'] as String? ?? '';
      if (status.isEmpty && action.isEmpty) {
        throw const AiRecordApiException();
      }
      return AiGeneratedRecord(status: status, action: action);
    } on AiRecordApiException {
      rethrow;
    } on Object {
      throw const AiRecordApiException();
    }
  }

  /// [10] 조치를 선택하지 않고 결과 확인을 눌렀을 때, 선택된 상태 키워드를
  /// 분석해 상황에 맞는 조치 2~3개를 추천받는다.
  Future<List<String>> suggestActions({
    required List<String> statusKeywords,
    String? facilityType,
    String? recordType,
  }) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/suggest-actions'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'statusKeywords': statusKeywords,
              'facilityType': ?facilityType,
              'recordType': ?recordType,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on Object {
      throw const AiRecordApiException();
    }

    if (response.statusCode != 200) {
      throw const AiRecordApiException();
    }

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? suggestions =
          decoded['suggestions'] as List<dynamic>?;
      return suggestions?.cast<String>() ?? const <String>[];
    } on Object {
      throw const AiRecordApiException();
    }
  }
}

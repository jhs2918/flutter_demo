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

  // [14] payload는 카드선택화면._buildPayload()가 만든 facility_type/
  // record_type/selections/... 형태를 그대로 최상위로 보낸다(추가 래핑
  // 없음) - 백엔드가 req.body를 바로 그 형태로 읽는다.
  Future<AiGeneratedRecord> generate(Map<String, dynamic> payload) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/generate'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
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
}

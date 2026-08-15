import 'dart:convert';

import 'package:http/http.dart' as http;

// [07] 백엔드 서버 주소. Railway 배포 후에는 아래 defaultValue를 실제 배포
// URL로 바꾸거나, 빌드 시 --dart-define=API_BASE_URL=https://xxxx.up.railway.app
// 로 지정한다. 기본값은 안드로이드 에뮬레이터에서 개발 PC의 localhost:3000
// (백엔드 로컬 실행)에 접속하기 위한 주소다.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

/// [07] /generate 호출이 실패했을 때 던지는 예외. 실패 사유(네트워크 오류,
/// 타임아웃, 서버 오류 등)와 무관하게 화면에는 항상 같은 안내 문구를 보여준다.
class AiRecordApiException implements Exception {
  const AiRecordApiException([this.message = '잠시 후 다시 시도해주세요']);

  final String message;

  @override
  String toString() => message;
}

/// [07] 선택된 카테고리별 항목을 백엔드 /generate에 전달해 AI가 작성한
/// 기록 문장을 받아온다.
class AiRecordApi {
  const AiRecordApi({this.baseUrl = kApiBaseUrl});

  final String baseUrl;

  Future<String> generate(Map<String, List<String>> selections) async {
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
      final String? text = decoded['text'] as String?;
      if (text == null || text.isEmpty) {
        throw const AiRecordApiException();
      }
      return text;
    } on AiRecordApiException {
      rethrow;
    } on Object {
      throw const AiRecordApiException();
    }
  }
}

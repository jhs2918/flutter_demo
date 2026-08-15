import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// [02-04] 카테고리별로 사용자가 추가한 커스텀 버튼을 SharedPreferences에 보관한다.
class CustomButtonRepository {
  static const String _storageKey = 'custom_category_buttons';

  /// 카테고리 id를 키로 하는 커스텀 버튼 목록을 불러온다. 저장된 값이 없으면 빈 맵을 반환한다.
  Future<Map<String, List<String>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <String, List<String>>{};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (String key, dynamic value) =>
            MapEntry(key, (value as List<dynamic>).cast<String>()),
      );
    } on Object {
      // 저장된 내용이 손상된 경우 앱이 아예 못 뜨는 것보다 빈 맵으로 시작하는 편이 낫다.
      return <String, List<String>>{};
    }
  }

  /// 카테고리별 커스텀 버튼 맵 전체를 JSON 문자열로 인코딩하여 저장한다.
  Future<void> save(Map<String, List<String>> customButtons) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(customButtons));
  }
}

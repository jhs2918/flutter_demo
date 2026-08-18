import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// [낱말카드 개편] 사용자가 "버튼 추가"로 직접 만든 낱말카드를
/// 카테고리+그룹별로 SharedPreferences에 저장한다. 키는
/// "categoryId::groupName" 형태.
class CustomCardItemRepository {
  static const String _storageKey = 'custom_card_items';

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

  Future<void> save(Map<String, List<String>> customItems) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(customItems));
  }
}

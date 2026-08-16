import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_name_group.dart';

/// [저장개편] 사용자가 이름을 붙여 만든 "내 저장" 그룹 목록을 SharedPreferences에
/// 보관한다. 자동 삭제되지 않는 영구 보관소다.
class SavedNameGroupRepository {
  static const String _storageKey = 'my_saved_name_groups';

  Future<List<SavedNameGroup>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <SavedNameGroup>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((dynamic item) =>
              SavedNameGroup.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      // 저장된 내용이 손상된 경우 앱이 아예 못 뜨는 것보다 빈 목록으로 시작하는 편이 낫다.
      return <SavedNameGroup>[];
    }
  }

  Future<void> save(List<SavedNameGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(groups.map((SavedNameGroup g) => g.toJson()).toList()),
    );
  }
}

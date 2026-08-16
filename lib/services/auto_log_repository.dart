import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_combination_entry.dart';

/// [저장개편] AI 문장을 생성할 때마다 자동으로 쌓이는 로그를 SharedPreferences에
/// 보관한다. 7일이 지난 기록을 걸러내는 것은 record_screen이 앱 시작 시 담당한다.
class AutoLogRepository {
  static const String _storageKey = 'auto_generation_log';

  Future<List<WordCombinationEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <WordCombinationEntry>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((dynamic item) =>
              WordCombinationEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      // 저장된 내용이 손상된 경우 앱이 아예 못 뜨는 것보다 빈 목록으로 시작하는 편이 낫다.
      return <WordCombinationEntry>[];
    }
  }

  Future<void> save(List<WordCombinationEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(entries.map((WordCombinationEntry e) => e.toJson()).toList()),
    );
  }
}

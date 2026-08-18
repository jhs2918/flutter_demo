import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_card_combination.dart';

/// [낱말카드 개편] 이름 붙여 저장한 카드 선택 + AI 결과 목록을
/// SharedPreferences에 보관한다. 이름이 곧 고유 키다.
class SavedCardCombinationRepository {
  static const String _storageKey = 'saved_card_combinations';

  Future<List<SavedCardCombination>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <SavedCardCombination>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) =>
                SavedCardCombination.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on Object {
      // 저장된 내용이 손상된 경우 앱이 아예 못 뜨는 것보다 빈 목록으로 시작하는 편이 낫다.
      return <SavedCardCombination>[];
    }
  }

  Future<void> save(List<SavedCardCombination> combinations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(
        combinations.map((SavedCardCombination c) => c.toJson()).toList(),
      ),
    );
  }
}

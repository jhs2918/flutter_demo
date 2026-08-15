import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_word_combination.dart';

/// [02-10] 저장된 단어 조합 목록을 SharedPreferences에 보관한다.
class SavedWordCombinationRepository {
  static const String _storageKey = 'saved_word_combinations';

  /// 저장된 단어 조합 목록을 순서대로 불러온다. 저장된 값이 없으면 빈 목록을 반환한다.
  Future<List<SavedWordCombination>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <SavedWordCombination>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((dynamic item) =>
              SavedWordCombination.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      // 저장된 내용이 손상된 경우 앱이 아예 못 뜨는 것보다 빈 목록으로 시작하는 편이 낫다.
      return <SavedWordCombination>[];
    }
  }

  /// 저장된 단어 조합 목록 전체를 JSON 문자열로 인코딩하여 저장한다.
  Future<void> save(List<SavedWordCombination> combinations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(
        combinations
            .map((SavedWordCombination combination) => combination.toJson())
            .toList(),
      ),
    );
  }
}

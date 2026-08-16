import 'word_combination_entry.dart';

/// [저장개편] 사용자가 직접 이름을 붙여 만든 "내 저장" 그룹. 같은 이름에
/// 여러 기록(entries)이 계속 누적될 수 있으며, 자동 삭제되지 않는다.
class SavedNameGroup {
  const SavedNameGroup({required this.name, required this.entries});

  final String name;
  final List<WordCombinationEntry> entries;

  // 그룹 정렬 기준: 그룹 안에서 가장 최근에 저장된 기록의 시각.
  DateTime get lastSavedAt {
    if (entries.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return entries
        .map((WordCombinationEntry e) => e.timestamp)
        .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'entries':
            entries.map((WordCombinationEntry e) => e.toJson()).toList(),
      };

  factory SavedNameGroup.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawEntries = json['entries'] as List<dynamic>;
    return SavedNameGroup(
      name: json['name'] as String,
      entries: rawEntries
          .map((dynamic e) =>
              WordCombinationEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

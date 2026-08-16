/// [저장개편] AI가 생성한 문장 한 건과, 그 문장을 만들 때 선택했던 단어
/// 조합을 함께 담는 기록. 자동 로그와 내 저장 목록이 공통으로 사용한다.
class WordCombinationEntry {
  const WordCombinationEntry({
    required this.timestamp,
    required this.selectedLabelsBySubCategoryId,
    required this.generatedText,
  });

  final DateTime timestamp;
  // 세부 카테고리 id별 선택되어 있던 버튼 라벨 목록.
  final Map<String, List<String>> selectedLabelsBySubCategoryId;
  final String generatedText;

  List<String> get words => <String>[
        for (final List<String> labels in selectedLabelsBySubCategoryId.values)
          ...labels,
      ];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestamp': timestamp.toIso8601String(),
        'selectedLabelsBySubCategoryId': selectedLabelsBySubCategoryId,
        'generatedText': generatedText,
      };

  factory WordCombinationEntry.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> selected =
        json['selectedLabelsBySubCategoryId'] as Map<String, dynamic>;
    return WordCombinationEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      selectedLabelsBySubCategoryId: selected.map(
        (String key, dynamic value) =>
            MapEntry(key, (value as List<dynamic>).cast<String>()),
      ),
      generatedText: json['generatedText'] as String,
    );
  }
}

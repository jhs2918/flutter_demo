/// [낱말카드 개편] 사용자가 이름을 붙여 저장한 카드 선택 + AI 생성 결과.
/// 서비스/등급과 무관하게 카드 키("categoryId::groupName::label")만으로
/// 선택 상태를 복원하므로, 저장할 때와 다른 서비스/등급에서 불러와도 그대로
/// 적용된다.
class SavedResultEntry {
  const SavedResultEntry({required this.label, required this.text});

  // "상태" / "조치" 또는 재요청 문구(예: "더 짧게 써줘").
  final String label;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'text': text,
  };

  factory SavedResultEntry.fromJson(Map<String, dynamic> json) =>
      SavedResultEntry(
        label: json['label'] as String,
        text: json['text'] as String,
      );
}

class SavedCardCombination {
  const SavedCardCombination({
    required this.name,
    required this.savedAt,
    required this.selectedKeys,
    required this.numericValues,
    required this.opinion,
    required this.results,
  });

  final String name;
  final DateTime savedAt;
  final List<String> selectedKeys;
  final Map<String, String> numericValues;
  final String opinion;
  final List<SavedResultEntry> results;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'savedAt': savedAt.toIso8601String(),
    'selectedKeys': selectedKeys,
    'numericValues': numericValues,
    'opinion': opinion,
    'results': results.map((SavedResultEntry e) => e.toJson()).toList(),
  };

  factory SavedCardCombination.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawNumeric =
        json['numericValues'] as Map<String, dynamic>;
    final List<dynamic> rawResults = json['results'] as List<dynamic>;
    return SavedCardCombination(
      name: json['name'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      selectedKeys: (json['selectedKeys'] as List<dynamic>).cast<String>(),
      numericValues: rawNumeric.map(
        (String key, dynamic value) => MapEntry(key, value as String),
      ),
      opinion: json['opinion'] as String,
      results: rawResults
          .map(
            (dynamic e) => SavedResultEntry.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

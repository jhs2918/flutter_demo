/// [낱말카드 개편][17] 저장한 카드 선택 + AI 생성 결과. 서비스/등급과 무관
/// 하게 카드 키("categoryId::groupName::label")만으로 선택 상태를 복원하므로,
/// 저장할 때와 다른 서비스/등급에서 불러와도 그대로 적용된다.
class SavedResultEntry {
  const SavedResultEntry({required this.label, required this.text});

  // 최초 생성 결과는 빈 문자열, 재요청 결과는 그 요청 문구(예: "더 짧게 써줘").
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

// [18] 저장 구조 개편: 저장할 때 이름(예: 수급자 이름·별칭)을 지정하고,
// 같은 이름으로 여러 번 저장하면 겹쳐쓰지 않고 그 이름 아래에 리스트로
// 쌓인다. savedAt(밀리초 단위 타임스탬프)은 같은 이름 안에서 각 저장
// 항목을 구분하는 고유 식별자 역할을 한다 - 같은 밀리초에 두 번 저장될
// 일은 사실상 없다.
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
      name: json['name'] as String? ?? '이름 없음',
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

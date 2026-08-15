/// [02-10] 사용자가 이름을 붙여 저장한 단어 조합 하나.
class SavedWordCombination {
  const SavedWordCombination({
    required this.name,
    required this.selectedLabelsBySubCategoryId,
  });

  // 저장 시 입력한 이름.
  final String name;
  // 세부 카테고리 id별 선택되어 있던 버튼 라벨 목록.
  final Map<String, List<String>> selectedLabelsBySubCategoryId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'selectedLabelsBySubCategoryId': selectedLabelsBySubCategoryId,
      };

  factory SavedWordCombination.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> selected =
        json['selectedLabelsBySubCategoryId'] as Map<String, dynamic>;
    return SavedWordCombination(
      name: json['name'] as String,
      selectedLabelsBySubCategoryId: selected.map(
        (String key, dynamic value) =>
            MapEntry(key, (value as List<dynamic>).cast<String>()),
      ),
    );
  }
}

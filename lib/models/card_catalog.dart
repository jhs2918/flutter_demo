/// [낱말카드 개편] assets/data/cards.json을 읽어 만든 카드 데이터 모델.
/// 카테고리 → 그룹 → 항목의 3단 구조이며, 컴포넌트에는 한글을 하드코딩하지
/// 않고 전부 이 데이터를 통해 렌더링한다.
library;

/// 항목/카테고리가 어느 서비스에서 노출되는지. "all"이면 방문요양·주간보호
/// 둘 다에서 노출된다.
enum CardService {
  all,
  visit,
  day;

  static CardService fromJson(String? value) {
    switch (value) {
      case 'visit':
        return CardService.visit;
      case 'day':
        return CardService.day;
      default:
        return CardService.all;
    }
  }

  // 현재 선택된 서비스(null이면 아직 선택 전 = 전부 노출) 기준으로 이
  // 서비스 값이 노출 대상인지 판단한다.
  bool visibleFor(CardService? selected) {
    if (selected == null || this == CardService.all) return true;
    return this == selected;
  }
}

/// 카드 한 장(단어 버튼 또는 숫자 입력 항목).
class CardItem {
  const CardItem({
    required this.label,
    required this.grades,
    required this.service,
    this.type,
    this.input,
    this.unit,
  });

  final String label;
  // 강조할 등급 목록. 비어있으면 어떤 등급에서도 강조되지 않는다.
  // 값은 "1" "2" "3" "4" "5" "인지" 중 하나.
  final List<String> grades;
  final CardService service;
  // "status"(관찰 상태) | "action"(조치). 숫자 입력 항목은 null일 수 있다.
  final String? type;
  // "number"면 버튼이 아니라 숫자 입력 필드로 렌더링한다.
  final String? input;
  // 숫자 입력 항목의 단위(예: "ml", "회").
  final String? unit;

  bool get isNumberInput => input == 'number';

  bool isHighlightedFor(String? grade) =>
      grade != null && grades.contains(grade);

  factory CardItem.fromJson(Map<String, dynamic> json) {
    return CardItem(
      label: json['label'] as String,
      grades:
          (json['grades'] as List<dynamic>?)?.cast<String>() ??
          const <String>[],
      service: CardService.fromJson(json['service'] as String?),
      type: json['type'] as String?,
      input: json['input'] as String?,
      unit: json['unit'] as String?,
    );
  }
}

/// 카테고리 안의 소그룹(예: "연하 상태", "조치", "수치 입력").
class CardGroup {
  const CardGroup({required this.name, required this.items});

  final String name;
  final List<CardItem> items;

  factory CardGroup.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems = json['items'] as List<dynamic>;
    return CardGroup(
      name: json['name'] as String,
      items: rawItems
          .map(
            (dynamic item) => CardItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// 대분류 카테고리(예: "③ 식사·영양").
class CardCategory {
  const CardCategory({
    required this.id,
    required this.name,
    required this.service,
    required this.groups,
  });

  final String id;
  final String name;
  final CardService service;
  final List<CardGroup> groups;

  factory CardCategory.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawGroups = json['groups'] as List<dynamic>;
    return CardCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      service: CardService.fromJson(json['service'] as String?),
      groups: rawGroups
          .map(
            (dynamic group) =>
                CardGroup.fromJson(group as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// cards.json 전체를 담는 최상위 카탈로그.
class CardCatalog {
  const CardCatalog({required this.categories});

  final List<CardCategory> categories;

  factory CardCatalog.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawCategories = json['categories'] as List<dynamic>;
    return CardCatalog(
      categories: rawCategories
          .map(
            (dynamic category) =>
                CardCategory.fromJson(category as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

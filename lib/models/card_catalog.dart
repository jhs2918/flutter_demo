/// [낱말카드 개편 v2] assets/data/cards.json을 읽어 만든 카드 데이터 모델.
/// 시설(방문요양/주간보호) → 기록유형(급여제공기록 등 5종) → 카테고리 → 그룹 →
/// 항목의 4단 구조이며, 컴포넌트에는 한글을 하드코딩하지 않고 전부 이 데이터를
/// 통해 렌더링한다. 등급 개념은 이 구조에는 없다(등급별 강조·분리 없음).
library;

/// 시설 종류. 서비스 선택 화면에서 고르며, 이후 어떤 record_type 목록을
/// 보여줄지의 기준이 된다.
enum CardService {
  visit,
  day;

  static CardService fromJson(String? value) {
    return value == 'day' ? CardService.day : CardService.visit;
  }
}

/// 카드 한 장(단어 버튼 또는 입력 항목).
class CardItem {
  const CardItem({required this.label, this.input, this.unit});

  final String label;
  // "number" | "text"면 버튼이 아니라 입력 필드로 렌더링한다. null이면 그냥
  // 눌러서 선택/해제하는 낱말 버튼.
  final String? input;
  // 입력 항목의 단위(예: "ml", "회", "분"). 텍스트 입력이면 보통 비워둔다.
  final String? unit;

  bool get isInputField => input == 'number' || input == 'text';
  bool get isNumericInput => input == 'number';

  factory CardItem.fromJson(Map<String, dynamic> json) {
    return CardItem(
      label: json['label'] as String,
      input: json['input'] as String?,
      unit: json['unit'] as String?,
    );
  }
}

/// 카테고리 안의 소그룹(예: "세면도움", "상태", "조치", "방향").
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

/// 대분류 카테고리(예: "신체활동지원", "피부상태").
class CardCategory {
  const CardCategory({
    required this.id,
    required this.name,
    required this.groups,
  });

  final String id;
  final String name;
  final List<CardGroup> groups;

  factory CardCategory.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawGroups = json['groups'] as List<dynamic>;
    return CardCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      groups: rawGroups
          .map(
            (dynamic group) =>
                CardGroup.fromJson(group as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// 기록유형(급여제공기록/상태변화일지/업무수행일지/사례관리/직원상담) 하나.
class CardRecordType {
  const CardRecordType({
    required this.id,
    required this.label,
    required this.categories,
  });

  final String id;
  final String label;
  final List<CardCategory> categories;

  factory CardRecordType.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawCategories = json['categories'] as List<dynamic>;
    return CardRecordType(
      id: json['id'] as String,
      label: json['label'] as String,
      categories: rawCategories
          .map(
            (dynamic category) =>
                CardCategory.fromJson(category as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// cards.json 전체를 담는 최상위 카탈로그. 시설별로 기록유형 목록을 갖는다.
class CardCatalog {
  const CardCatalog({required this.visit, required this.day});

  final List<CardRecordType> visit;
  final List<CardRecordType> day;

  List<CardRecordType> recordTypesFor(CardService service) =>
      service == CardService.visit ? visit : day;

  CardRecordType? recordTypeFor(CardService service, String recordTypeId) {
    for (final CardRecordType rt in recordTypesFor(service)) {
      if (rt.id == recordTypeId) return rt;
    }
    return null;
  }

  // [버그 회피] 시설별로 파일이 나뉘어 있으므로(자세한 이유는 pubspec.yaml
  // 주석 참고) 각 시설의 record type 배열을 따로 받는다.
  factory CardCatalog.fromParts({
    required List<dynamic> visitJson,
    required List<dynamic> dayJson,
  }) {
    List<CardRecordType> parse(List<dynamic> raw) => raw
        .map(
          (dynamic rt) => CardRecordType.fromJson(rt as Map<String, dynamic>),
        )
        .toList();

    return CardCatalog(visit: parse(visitJson), day: parse(dayJson));
  }
}

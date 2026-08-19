import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/card_catalog.dart';
import '../models/saved_card_combination.dart';
import '../services/ai_record_api.dart';
import '../services/card_catalog_repository.dart';
import '../services/custom_card_item_repository.dart';
import '../services/saved_card_combination_repository.dart';
import '../state/font_scale_controller.dart';
import '../theme/pastel_palette.dart';
import '../widgets/ai_generating_dialog.dart';
import '../widgets/font_scale_bar.dart';
import 'ai_generation_result_screen.dart';

const Color _kNeutralBg = Color(0xFFF1F1F1);
const Color _kNeutralText = Color(0xFF444444);
// 내가 직접 추가한 낱말카드를 구분하는 색(연두). 선택 테두리(보라)와
// 겹쳐도 헷갈리지 않도록 다른 색상 계열을 쓴다.
const Color _kCustomBg = Color(0xFFD8F5DE);
const Color _kCustomText = Color(0xFF1B6B3A);
// 값이 입력된 입력 카드 강조색.
const Color _kNumberFilledBg = Color(0xFFF3E9FF);

// [공통버튼_조치상황] 전역 모듈 - 어떤 카테고리에서도 최하단에 고정으로
// 붙는 공통 버튼. 데이터(cards.json)에 카테고리마다 반복해서 넣지 않고
// 화면에서 매 카테고리 그룹 목록 끝에 덧붙인다.
const String _kCareLevelGroupName = '조치상황';

/// [낱말카드 개편 v2][3단계] 카테고리(접기/펼치기) → 그룹 → 항목 카드를 보여주고
/// 선택하는 화면. 시설·기록유형에 맞는 카테고리만 이미 cards.json에서 갈라져
/// 있으므로 이 화면에서는 별도 필터링 없이 그대로 보여준다(등급 개념 없음).
class CardSelectScreen extends StatefulWidget {
  const CardSelectScreen({
    super.key,
    required this.service,
    required this.recordTypeId,
    required this.recordTypeLabel,
  });

  final CardService service;
  final String recordTypeId;
  final String recordTypeLabel;

  @override
  State<CardSelectScreen> createState() => _CardSelectScreenState();
}

class _CardSelectScreenState extends State<CardSelectScreen> {
  final CardCatalogRepository _repository = CardCatalogRepository();
  final CustomCardItemRepository _customRepository = CustomCardItemRepository();
  final SavedCardCombinationRepository _savedRepository =
      SavedCardCombinationRepository();
  final AiRecordApi _aiRecordApi = const AiRecordApi();
  final TextEditingController _opinionController = TextEditingController();

  CardCatalog? _catalog;
  final Set<String> _selected = <String>{};
  final Map<String, String> _numericValues = <String, String>{};
  // [10] 조치 없이 결과 확인을 눌렀을 때 추천받아 사용자가 고른 조치.
  // 재요청(onRegenerate) 시에도 같은 세션 동안은 계속 포함시킨다.
  List<String> _recommendedActions = <String>[];
  // "categoryId::groupName" -> 사용자가 직접 추가한 라벨 목록.
  Map<String, List<String>> _customItems = <String, List<String>>{};
  // 이름 붙여 저장한 카드 선택 + AI 결과 목록. 최근 저장순으로 정렬해 둔다.
  List<SavedCardCombination> _savedCombinations = <SavedCardCombination>[];
  // 카테고리 펼침 시 그 위치로 스크롤하기 위한 카드별 키.
  final Map<String, GlobalKey> _categoryKeys = <String, GlobalKey>{};
  final ScrollController _scrollController = ScrollController();
  // [13] 한 번에 하나의 카테고리만 펼쳐지도록(아코디언) 각 카테고리의
  // 펼침 상태를 직접 제어하기 위한 컨트롤러.
  final Map<String, ExpansibleController> _expansionControllers =
      <String, ExpansibleController>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _opinionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final CardCatalog catalog = await _repository.load();
    final Map<String, List<String>> customItems = await _customRepository
        .load();
    await _loadSavedCombinations();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _customItems = customItems;
    });
  }

  Future<void> _loadSavedCombinations() async {
    final List<SavedCardCombination> combos = await _savedRepository.load();
    combos.sort(
      (SavedCardCombination a, SavedCardCombination b) =>
          b.savedAt.compareTo(a.savedAt),
    );
    if (!mounted) return;
    setState(() => _savedCombinations = combos);
  }

  String _key(CardCategory category, CardGroup group, CardItem item) =>
      '${category.id}::${group.name}::${item.label}';

  String _groupKey(CardCategory category, CardGroup group) =>
      '${category.id}::${group.name}';

  GlobalKey _keyFor(String categoryId) =>
      _categoryKeys.putIfAbsent(categoryId, GlobalKey.new);

  ExpansibleController _expansionControllerFor(String categoryId) =>
      _expansionControllers.putIfAbsent(
        categoryId,
        ExpansibleController.new,
      );

  // [13] 카테고리 안에서 실제로 선택된 낱말(입력 필드 제외) 개수. 헤더 옆
  // 배지에 쓴다.
  int _selectedCountFor(CardCategory category) {
    int count = 0;
    for (final CardGroup group in _groupsFor(category)) {
      for (final CardItem item in _itemsWithCustom(category, group)) {
        if (!item.isInputField &&
            _selected.contains(_key(category, group, item))) {
          count++;
        }
      }
    }
    return count;
  }

  String get _facilityLabel =>
      widget.service == CardService.visit ? '방문요양' : '주간보호';

  List<CardCategory> get _visibleCategories {
    final CardCatalog? catalog = _catalog;
    if (catalog == null) return const <CardCategory>[];
    return catalog
            .recordTypeFor(widget.service, widget.recordTypeId)
            ?.categories ??
        const <CardCategory>[];
  }

  // 카테고리의 실제 그룹 + 모든 카테고리 최하단에 고정으로 붙는 공통
  // 조치상황 버튼 그룹.
  List<CardGroup> _groupsFor(CardCategory category) => <CardGroup>[
    ...category.groups,
    const CardGroup(
      name: _kCareLevelGroupName,
      items: <CardItem>[
        CardItem(label: '스스로하기'),
        CardItem(label: '지켜보기'),
        CardItem(label: '부분도움'),
        CardItem(label: '완전도움'),
      ],
    ),
  ];

  // 그룹 안의 기본 제공 항목 + 사용자가 추가한 커스텀 항목을 합친다.
  List<CardItem> _itemsWithCustom(CardCategory category, CardGroup group) {
    final List<String> customLabels =
        _customItems[_groupKey(category, group)] ?? const <String>[];
    if (customLabels.isEmpty) return group.items;

    return <CardItem>[
      ...group.items,
      for (final String label in customLabels) CardItem(label: label),
    ];
  }

  bool _isCustom(CardCategory category, CardGroup group, String label) {
    final List<String>? customLabels = _customItems[_groupKey(category, group)];
    return customLabels != null && customLabels.contains(label);
  }

  // 공통 조치상황 그룹은 고정 어휘라 커스텀 추가를 허용하지 않는다. 그 외
  // 그룹은 입력 전용(그룹의 모든 항목이 입력 필드)이 아니면 추가할 수 있다.
  bool _allowsCustomAdd(CardGroup group) =>
      group.name != _kCareLevelGroupName &&
      group.items.any((CardItem i) => !i.isInputField);

  // [10] "조치" 그룹인지 판단한다. "조치" 단독 그룹뿐 아니라 "복약도움 조치"
  // 처럼 접미어로 붙는 경우도 포함하되, 공통 조치상황(스스로하기/지켜보기/
  // 부분도움/완전도움) 그룹은 다른 개념이라 제외한다("조치상황"은 "조치"로
  // 끝나지 않으므로 자연히 제외됨).
  bool _isActionGroupName(String name) => name.endsWith('조치');

  bool get _hasActionGroupsAvailable => _visibleCategories.any(
    (CardCategory c) => c.groups.any((CardGroup g) => _isActionGroupName(g.name)),
  );

  bool get _hasAnyActionSelected {
    for (final CardCategory category in _visibleCategories) {
      for (final CardGroup group in category.groups) {
        if (!_isActionGroupName(group.name)) continue;
        for (final CardItem item in _itemsWithCustom(category, group)) {
          if (_selected.contains(_key(category, group, item))) return true;
        }
      }
    }
    return false;
  }

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  // 선택 키("categoryId::groupName::label")에서 화면에 보여줄 라벨만 뽑는다.
  String _labelForKey(String key) => key.split('::').last;

  void _clearAllSelected() {
    if (_selected.isEmpty) return;
    setState(() => _selected.clear());
  }

  // 저장/불러오기 키는 카테고리+그룹+라벨로만 만들어지므로, 저장할 때와
  // 다른 시설·기록유형 화면에서 불러와도 겹치는 항목은 그대로 맞는다.
  void _applyCombination(SavedCardCombination combo) {
    setState(() {
      _selected
        ..clear()
        ..addAll(combo.selectedKeys);
      _numericValues
        ..clear()
        ..addAll(combo.numericValues);
      _opinionController.text = combo.opinion;
    });
  }

  Future<void> _saveCombination(
    String name,
    List<SavedResultEntry> results,
  ) async {
    final SavedCardCombination combo = SavedCardCombination(
      name: name,
      savedAt: DateTime.now(),
      selectedKeys: _selected.toList(),
      numericValues: <String, String>{
        for (final MapEntry<String, String> entry in _numericValues.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value,
      },
      opinion: _opinionController.text.trim(),
      results: results,
    );
    final List<SavedCardCombination> updated =
        <SavedCardCombination>[
          ..._savedCombinations.where(
            (SavedCardCombination c) => c.name != name,
          ),
          combo,
        ]..sort(
          (SavedCardCombination a, SavedCardCombination b) =>
              b.savedAt.compareTo(a.savedAt),
        );
    setState(() => _savedCombinations = updated);
    await _savedRepository.save(updated);
  }

  Future<void> _deleteCombination(String name) async {
    final List<SavedCardCombination> updated = _savedCombinations
        .where((SavedCardCombination c) => c.name != name)
        .toList();
    setState(() => _savedCombinations = updated);
    await _savedRepository.save(updated);
  }

  Future<void> _showSavedCombinationSheet(SavedCardCombination combo) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: kAppBackground,
      builder: (BuildContext sheetContext) => _SavedCombinationSheet(
        combination: combo,
        labelOf: _labelForKey,
        onLoad: () {
          _applyCombination(combo);
          Navigator.of(sheetContext).pop();
        },
        onDelete: () async {
          await _deleteCombination(combo.name);
          if (!sheetContext.mounted) return;
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  // [13] 카테고리가 펼쳐지면 - 아코디언처럼 다른 카테고리는 전부 닫고
  // (한 번에 하나만 펼쳐짐) - 그 카드 위치로 부드럽게 스크롤한다. 다른
  // 카테고리를 접는 애니메이션(기본 200ms)과 스크롤 대상 계산이 동시에
  // 돌면 접히는 중간 크기를 기준으로 스크롤 위치를 계산해버려 엉뚱한
  // 곳으로 스크롤된다 - 접는 애니메이션이 끝날 시간을 먼저 기다린다.
  Future<void> _handleExpansion(String categoryId, bool expanded) async {
    final bool collapsingOthers = expanded &&
        _expansionControllers.entries.any(
          (MapEntry<String, ExpansibleController> entry) =>
              entry.key != categoryId && entry.value.isExpanded,
        );
    if (expanded) {
      for (final MapEntry<String, ExpansibleController> entry
          in _expansionControllers.entries) {
        if (entry.key != categoryId && entry.value.isExpanded) {
          entry.value.collapse();
        }
      }
    }
    if (!expanded) return;
    if (collapsingOthers) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } else {
      await Future<void>.delayed(Duration.zero);
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? cardContext =
          _categoryKeys[categoryId]?.currentContext;
      if (cardContext == null || !cardContext.mounted) return;
      Scrollable.ensureVisible(
        cardContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    });
  }

  Future<void> _addCustomItem(CardCategory category, CardGroup group) async {
    final String? label = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _AddCardDialog(),
    );
    if (label == null || label.trim().isEmpty) return;
    final String trimmed = label.trim();
    final String key = _groupKey(category, group);
    final List<String> existing = _customItems[key] ?? const <String>[];
    if (existing.contains(trimmed) ||
        group.items.any((CardItem i) => i.label == trimmed)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이미 있는 카드입니다.')));
      return;
    }

    setState(() {
      _customItems = <String, List<String>>{
        ..._customItems,
        key: <String>[...existing, trimmed],
      };
    });
    await _customRepository.save(_customItems);
  }

  Future<void> _deleteCustomItem(
    CardCategory category,
    CardGroup group,
    String label,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('카드 삭제'),
            content: Text('"$label" 카드를 삭제할까요?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final String key = _groupKey(category, group);
    setState(() {
      final List<String> updated = <String>[
        ...(_customItems[key] ?? <String>[]),
      ]..remove(label);
      _customItems = <String, List<String>>{..._customItems, key: updated};
      _selected.remove('${category.id}::${group.name}::$label');
      _numericValues.remove('${category.id}::${group.name}::$label');
    });
    await _customRepository.save(_customItems);
  }

  // [14] 방문요양어플지침.txt가 요구하는 facility_type/record_type/
  // care_level/body_part 필드를 실제로 채워 보낸다. 이전에는 카테고리 안의
  // 상태·조치·조치상황·방향·부위·증상 항목이 전부 한 리스트로 뭉쳐져
  // 카테고리명 하나로만 보내졌다(예: "피부상태": ["건조함", "보습제 도포"]) -
  // AI가 어떤 단어가 관찰된 상태이고 어떤 게 취한 조치인지 라벨만 보고
  // 추측해야 했던 게 환각(입력에 없는 내용을 지어내는 문제)의 원인 중
  // 하나로 보인다. 이제 카테고리별로 역할을 나눠서 명시적으로 보낸다.
  //
  // 원 지침은 카테고리 하나·body_part 하나만 고르는 단일 선택 흐름을
  // 전제로 한 스키마이지만, 지금 앱은 여러 카테고리를 한꺼번에 채워서
  // 제출하므로 care_level/body_part를 카테고리별로 중첩시켜 보낸다(지침의
  // 필드명은 그대로 유지).
  Map<String, dynamic> _buildPayload({String? additionalRequest}) {
    final Map<String, dynamic> selections = <String, dynamic>{};
    final List<String> inputLines = <String>[];

    for (final CardCategory category in _visibleCategories) {
      final List<String> statusItems = <String>[];
      final List<String> actionItems = <String>[];
      final List<String> careLevelItems = <String>[];
      final List<String> directionItems = <String>[];
      final List<String> partItems = <String>[];
      final List<String> symptomItems = <String>[];
      final List<String> genericItems = <String>[];

      for (final CardGroup group in _groupsFor(category)) {
        for (final CardItem item in _itemsWithCustom(category, group)) {
          final String key = _key(category, group, item);
          if (item.isInputField) {
            final String? value = _numericValues[key];
            if (value != null && value.trim().isNotEmpty) {
              inputLines.add(
                '${category.name}·${item.label} ${value.trim()}${item.unit ?? ''}',
              );
            }
            continue;
          }
          if (!_selected.contains(key)) continue;

          switch (group.name) {
            case _kCareLevelGroupName:
              careLevelItems.add(item.label);
            case '방향':
              directionItems.add(item.label);
            case '부위':
              partItems.add(item.label);
            case '증상':
              symptomItems.add(item.label);
            default:
              if (_isActionGroupName(group.name)) {
                actionItems.add(item.label);
              } else if (group.name.endsWith('상태')) {
                statusItems.add(item.label);
              } else {
                genericItems.add(item.label);
              }
          }
        }
      }

      final Map<String, dynamic> categoryPayload = <String, dynamic>{
        if (statusItems.isNotEmpty) 'status': statusItems,
        if (actionItems.isNotEmpty) 'action': actionItems,
        if (careLevelItems.isNotEmpty) 'care_level': careLevelItems,
        if (directionItems.isNotEmpty ||
            partItems.isNotEmpty ||
            symptomItems.isNotEmpty)
          'body_part': <String, dynamic>{
            if (directionItems.isNotEmpty) 'direction': directionItems,
            if (partItems.isNotEmpty) 'part': partItems,
            if (symptomItems.isNotEmpty) 'symptom': symptomItems,
          },
        if (genericItems.isNotEmpty) 'items': genericItems,
      };
      if (categoryPayload.isNotEmpty) {
        selections[category.name] = categoryPayload;
      }
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'facility_type': widget.service == CardService.visit
          ? 'home_care'
          : 'day_care',
      'record_type': widget.recordTypeLabel,
      if (selections.isNotEmpty) 'selections': selections,
    };

    final String opinion = _opinionController.text.trim();
    if (inputLines.isNotEmpty) payload['입력값'] = inputLines;
    if (opinion.isNotEmpty) payload['extra_note'] = opinion;
    if (_recommendedActions.isNotEmpty) payload['추천조치'] = _recommendedActions;
    if (additionalRequest != null && additionalRequest.trim().isNotEmpty) {
      payload['추가요청'] = additionalRequest.trim();
    }
    return payload;
  }

  bool get _hasAnyContent {
    if (_selected.isNotEmpty) return true;
    if (_opinionController.text.trim().isNotEmpty) return true;
    return _numericValues.values.any((String v) => v.trim().isNotEmpty);
  }

  // [12] 결과 화면 위에 "어떤 단어를 선택했는지" 보여주기 위한 목록. 카드
  // 선택 + (조치 미선택 팝업에서) 사용자가 고른 추천 조치까지 포함한다.
  List<String> get _selectedWordLabels => <String>[
    ..._selected.map(_labelForKey),
    ..._recommendedActions,
  ];

  // [10] 조치 항목 없이 결과 확인을 눌렀을 때, 선택된 상태 키워드로 조치를
  // 추천받아 팝업으로 보여준다. 조치를 이미 선택했거나 추천할 조치 그룹
  // 자체가 없는 기록유형이면 그냥 넘어간다.
  Future<void> _maybeSuggestActions() async {
    if (_hasAnyActionSelected || !_hasActionGroupsAvailable) return;
    final List<String> statusKeywords = _selected.map(_labelForKey).toList();
    if (statusKeywords.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          const AiGeneratingDialog(message: '상태에 맞는 조치를 분석하고 있어요...'),
    );

    List<String> suggestions;
    try {
      suggestions = await _aiRecordApi.suggestActions(
        statusKeywords: statusKeywords,
        facilityType: _facilityLabel,
        recordType: widget.recordTypeLabel,
      );
    } on AiRecordApiException {
      // 추천은 부가 기능이므로 실패해도 조용히 넘어가고 문장 생성은 계속한다.
      suggestions = const <String>[];
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (suggestions.isEmpty) return;

    final List<String>? chosen = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          _ActionSuggestionDialog(suggestions: suggestions),
    );
    if (!mounted || chosen == null) return;
    setState(() => _recommendedActions = chosen);
  }

  Future<void> _generate() async {
    _recommendedActions = <String>[];
    await _maybeSuggestActions();
    if (!mounted) return;

    final Map<String, dynamic> payload = _buildPayload();
    final List<String> selectedLabels = _selectedWordLabels;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const AiGeneratingDialog(),
    );

    AiGeneratedRecord record;
    try {
      record = await _aiRecordApi.generate(payload);
    } on AiRecordApiException catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AiGenerationResultScreen(
          initialStatusText: record.status,
          initialActionText: record.action,
          selectedLabels: selectedLabels,
          onRegenerate: (String additionalRequest) => _aiRecordApi
              .generate(_buildPayload(additionalRequest: additionalRequest))
              .then(
                (AiGeneratedRecord r) => <String>[
                  r.status,
                  r.action,
                ].where((String s) => s.isNotEmpty).join(' '),
              ),
          onSave: _saveCombination,
        ),
      ),
    );
    // 결과 화면에서 저장했을 수 있으니 목록을 새로 불러온다.
    await _loadSavedCombinations();
  }

  @override
  Widget build(BuildContext context) {
    final double scale = FontScaleScope.of(context).scale;
    final CardCatalog? catalog = _catalog;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Text(widget.recordTypeLabel),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                const FontScaleBar(),
                if (_savedCombinations.isNotEmpty)
                  _SavedCombinationsBar(
                    combinations: _savedCombinations,
                    onTap: _showSavedCombinationSheet,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        '${widget.recordTypeLabel} · $_facilityLabel',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kSubHeaderColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '선택 항목 ${_selected.length}개',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kAccentPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                // [버그 회피] ListView(children:)도 내부적으로 Sliver를 쓰기
                // 때문에 뷰포트 근처 항목만 지연 생성된다. 카테고리가 많은
                // 기록유형(간호 및 처치 등)을 대비해 전부 즉시 빌드하는
                // SingleChildScrollView + Column으로 만든다.
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Column(
                      children: <Widget>[
                        for (final CardCategory category in _visibleCategories)
                          KeyedSubtree(
                            key: _keyFor(category.id),
                            child: _CategoryPanel(
                              category: category,
                              scale: scale,
                              selectedCount: _selectedCountFor(category),
                              controller: _expansionControllerFor(
                                category.id,
                              ),
                              groups: _groupsFor(category),
                              itemsOf: (CardGroup group) =>
                                  _itemsWithCustom(category, group),
                              keyOf: (CardGroup group, CardItem item) =>
                                  _key(category, group, item),
                              isSelected: _selected.contains,
                              isCustom: (CardGroup group, String label) =>
                                  _isCustom(category, group, label),
                              allowsCustomAdd: _allowsCustomAdd,
                              onToggle: _toggle,
                              onAddCustom: (CardGroup group) =>
                                  _addCustomItem(category, group),
                              onDeleteCustom: (CardGroup group, String label) =>
                                  _deleteCustomItem(category, group, label),
                              numericValues: _numericValues,
                              onNumericChanged: (String key, String value) {
                                setState(() => _numericValues[key] = value);
                              },
                              onExpansionChanged: (bool expanded) =>
                                  _handleExpansion(category.id, expanded),
                            ),
                          ),
                        _OpinionSection(
                          controller: _opinionController,
                          scale: scale,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selected.isNotEmpty)
                  _SelectedItemsBar(
                    scale: scale,
                    labels: _selected.map(_labelForKey).toList(),
                    onRemove: (String label) {
                      final String? key = _selected.cast<String?>().firstWhere(
                        (String? k) => k != null && _labelForKey(k) == label,
                        orElse: () => null,
                      );
                      if (key != null) _toggle(key);
                    },
                    onClearAll: _clearAllSelected,
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _hasAnyContent ? _generate : null,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('문장 생성'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// [10] 조치 없이 결과 확인을 눌렀을 때 뜨는 팝업. AI가 추천한 조치 2~3개를
// 토글로 고를 수 있고, [선택 완료]는 고른 조치를, [조치 없이 계속]은 빈
// 목록을 반환한다. 둘 중 하나를 눌러야만 닫힌다(뒤로가기로 닫히지 않음).
class _ActionSuggestionDialog extends StatefulWidget {
  const _ActionSuggestionDialog({required this.suggestions});

  final List<String> suggestions;

  @override
  State<_ActionSuggestionDialog> createState() =>
      _ActionSuggestionDialogState();
}

class _ActionSuggestionDialogState extends State<_ActionSuggestionDialog> {
  final Set<String> _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('조치를 선택하지 않으셨어요'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('선택하신 상태에 어울리는 조치를 추천해드려요.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String suggestion in widget.suggestions)
                  FilterChip(
                    label: Text(suggestion),
                    selected: _picked.contains(suggestion),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _picked.add(suggestion);
                        } else {
                          _picked.remove(suggestion);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(const <String>[]),
            child: const Text('조치 없이 계속'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_picked.toList()),
            child: const Text('선택 완료'),
          ),
        ],
      ),
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.category,
    required this.scale,
    required this.selectedCount,
    required this.controller,
    required this.groups,
    required this.itemsOf,
    required this.keyOf,
    required this.isSelected,
    required this.isCustom,
    required this.allowsCustomAdd,
    required this.onToggle,
    required this.onAddCustom,
    required this.onDeleteCustom,
    required this.numericValues,
    required this.onNumericChanged,
    required this.onExpansionChanged,
  });

  final CardCategory category;
  final double scale;
  // [13] 이 카테고리 안에서 선택된 낱말 개수. 0이면 배지를 숨긴다.
  final int selectedCount;
  // [13] 아코디언(한 번에 하나만 펼침) 동작을 위한 외부 제어 컨트롤러.
  final ExpansibleController controller;
  final List<CardGroup> groups;
  final List<CardItem> Function(CardGroup group) itemsOf;
  final String Function(CardGroup group, CardItem item) keyOf;
  final bool Function(String key) isSelected;
  final bool Function(CardGroup group, String label) isCustom;
  final bool Function(CardGroup group) allowsCustomAdd;
  final ValueChanged<String> onToggle;
  final ValueChanged<CardGroup> onAddCustom;
  final void Function(CardGroup group, String label) onDeleteCustom;
  final Map<String, String> numericValues;
  final void Function(String key, String value) onNumericChanged;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    // ExpansionTile의 헤더는 ListTile이라 잉크 효과를 가장 가까운 Material
    // 조상에 그린다. 배경색을 바깥 DecoratedBox/Container에 두면 그 위에서
    // 잉크가 가려진다는 프레임워크 경고가 뜨므로, 배경은 Material에 주고
    // 테두리만 별도 Container로 그린다.
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            controller: controller,
            onExpansionChanged: onExpansionChanged,
            title: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kCardTitleColor,
                    ),
                  ),
                ),
                if (selectedCount > 0) ...<Widget>[
                  SizedBox(width: 8 * scale),
                  _SelectedCountBadge(count: selectedCount, scale: scale),
                ],
              ],
            ),
            // 펼쳐졌을 때 헤더(흰색)와 구분되도록 내용 영역에 연한 배경색을
            // 준다. ExpansionTile.backgroundColor는 헤더까지 같이 물들여서
            // 대신 children을 감싸는 Container로 처리한다.
            children: <Widget>[
              Container(
                color: kPanelBg,
                child: Column(
                  children: <Widget>[
                    for (final CardGroup group in groups)
                      _GroupSection(
                        group: group,
                        scale: scale,
                        items: itemsOf(group),
                        keyOf: (CardItem item) => keyOf(group, item),
                        isSelected: isSelected,
                        isCustom: (String label) => isCustom(group, label),
                        showAddButton: allowsCustomAdd(group),
                        onToggle: onToggle,
                        onAddCustom: () => onAddCustom(group),
                        onDeleteCustom: (String label) =>
                            onDeleteCustom(group, label),
                        numericValues: numericValues,
                        onNumericChanged: onNumericChanged,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// [13] 카테고리 헤더 옆에 붙는 "이 안에서 N개 선택함" 배지.
class _SelectedCountBadge extends StatelessWidget {
  const _SelectedCountBadge({required this.count, required this.scale});

  final int count;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: kAccentPurple,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.scale,
    required this.items,
    required this.keyOf,
    required this.isSelected,
    required this.isCustom,
    required this.showAddButton,
    required this.onToggle,
    required this.onAddCustom,
    required this.onDeleteCustom,
    required this.numericValues,
    required this.onNumericChanged,
  });

  final CardGroup group;
  final double scale;
  final List<CardItem> items;
  final String Function(CardItem item) keyOf;
  final bool Function(String key) isSelected;
  final bool Function(String label) isCustom;
  final bool showAddButton;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddCustom;
  final ValueChanged<String> onDeleteCustom;
  final Map<String, String> numericValues;
  final void Function(String key, String value) onNumericChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && !showAddButton) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 14 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            group.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: kSubHeaderColor,
            ),
          ),
          SizedBox(height: 8 * scale),
          Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: <Widget>[
              for (final CardItem item in items)
                if (item.isInputField)
                  _NumberInputChip(
                    scale: scale,
                    label: item.label,
                    unit: item.unit ?? '',
                    value: numericValues[keyOf(item)] ?? '',
                    isNumeric: item.isNumericInput,
                    onChanged: (String value) =>
                        onNumericChanged(keyOf(item), value),
                  )
                else
                  _CardItemChip(
                    scale: scale,
                    label: item.label,
                    selected: isSelected(keyOf(item)),
                    isCustom: isCustom(item.label),
                    onTap: () => onToggle(keyOf(item)),
                    onDelete: isCustom(item.label)
                        ? () => onDeleteCustom(item.label)
                        : null,
                  ),
              if (showAddButton)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18, color: kAccentPurple),
                  label: const Text('버튼 추가'),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: kCardBorder),
                  onPressed: onAddCustom,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// 배경색 = 내가 추가한 카드 여부, 테두리+체크 아이콘 = 선택 여부. 서로 다른
// 시각 채널이라 겹쳐도(배경+테두리) 항상 구분된다.
class _CardItemChip extends StatelessWidget {
  const _CardItemChip({
    required this.scale,
    required this.label,
    required this.selected,
    required this.isCustom,
    required this.onTap,
    this.onDelete,
  });

  final double scale;
  final String label;
  final bool selected;
  final bool isCustom;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    // [13] 선택 여부가 배경색으로도 드러나야 한다는 요청 - 선택되면 테두리·
    // 체크 아이콘뿐 아니라 배경도 진한 보라로 바뀐다(기존 미사용 상태였던
    // kWordButtonSelectedBg/kWordButtonSelectedText를 재사용). 커스텀 카드
    // 표시(연두 배경)는 선택되지 않았을 때만 보이고, 선택되면 별 아이콘으로만
    // 구분한다 - 두 배경색이 동시에 경쟁하면 오히려 선택 여부가 덜 도드라진다.
    final Color bg = selected
        ? kWordButtonSelectedBg
        : (isCustom ? _kCustomBg : _kNeutralBg);
    final Color textColor = selected
        ? kWordButtonSelectedText
        : (isCustom ? _kCustomText : _kNeutralText);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onDelete,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 10 * scale,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? kCardSelectedBorder : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                Icon(Icons.check_circle, size: 16, color: textColor),
                SizedBox(width: 6 * scale),
              ],
              Text(
                label,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              if (isCustom) ...<Widget>[
                SizedBox(width: 4 * scale),
                Icon(Icons.star, size: 12 * scale, color: textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// [입력 카드] 탭하면 값이 바로 열리지 않고 다이얼로그가 떠서 그 안에서
// 입력한다. 값이 있으면 카드 자체에도 값이 요약되어 보인다. 숫자(input:
// "number")면 숫자 키패드, 그 외(input: "text", 예: 차량번호)는 일반
// 텍스트 입력을 쓴다.
class _NumberInputChip extends StatelessWidget {
  const _NumberInputChip({
    required this.scale,
    required this.label,
    required this.unit,
    required this.value,
    required this.isNumeric,
    required this.onChanged,
  });

  final double scale;
  final String label;
  final String unit;
  final String value;
  final bool isNumeric;
  final ValueChanged<String> onChanged;

  Future<void> _open(BuildContext context) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _NumberInputDialog(
        label: label,
        unit: unit,
        initialValue: value,
        isNumeric: isNumeric,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 10 * scale,
          ),
          decoration: BoxDecoration(
            color: hasValue ? _kNumberFilledBg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasValue ? kAccentPurple : kCardBorder,
              width: hasValue ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isNumeric ? Icons.numbers : Icons.edit,
                size: 16,
                color: kAccentPurple,
              ),
              SizedBox(width: 6 * scale),
              Text(
                hasValue ? '$label $value$unit' : label,
                style: const TextStyle(
                  color: kCardTitleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// [입력 카드] 다이얼로그. _AddCardDialog와 같은 이유로 컨트롤러를 자체
// 소유/해제한다.
class _NumberInputDialog extends StatefulWidget {
  const _NumberInputDialog({
    required this.label,
    required this.unit,
    required this.initialValue,
    required this.isNumeric,
  });

  final String label;
  final String unit;
  final String initialValue;
  final bool isNumeric;

  @override
  State<_NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<_NumberInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(suffixText: widget.unit),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

// "버튼 추가" 새 낱말카드 이름 입력 다이얼로그.
class _AddCardDialog extends StatefulWidget {
  const _AddCardDialog();

  @override
  State<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<_AddCardDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('버튼 추가'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '카드에 표시할 문구'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('추가'),
        ),
      ],
    );
  }
}

// 화면 최상단에 이름 붙여 저장한 조합을 최근 저장순으로 가로 스크롤
// 표시한다. 탭하면 상세 시트가 열린다.
class _SavedCombinationsBar extends StatelessWidget {
  const _SavedCombinationsBar({
    required this.combinations,
    required this.onTap,
  });

  final List<SavedCardCombination> combinations;
  final ValueChanged<SavedCardCombination> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: combinations.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int index) {
            final SavedCardCombination combo = combinations[index];
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onTap(combo),
              child: Chip(
                avatar: const Icon(Icons.star, size: 16, color: kAccentPurple),
                label: Text(combo.name),
                backgroundColor: kWordButtonBg,
                labelStyle: const TextStyle(
                  color: kWordButtonText,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
              ),
            );
          },
        ),
      ),
    );
  }
}

// 문장생성 버튼 바로 위: 지금까지 클릭(선택)한 카드 목록. 하나씩 삭제하거나
// 한 번에 전체 삭제할 수 있다.
class _SelectedItemsBar extends StatelessWidget {
  const _SelectedItemsBar({
    required this.scale,
    required this.labels,
    required this.onRemove,
    required this.onClearAll,
  });

  final double scale;
  final List<String> labels;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        10 * scale,
        16 * scale,
        4 * scale,
      ),
      decoration: const BoxDecoration(
        color: kPanelBg,
        border: Border(top: BorderSide(color: kCardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '선택한 항목 (${labels.length}개)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kCardTitleColor,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onClearAll,
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('전체 삭제'),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 96 * scale),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8 * scale,
                runSpacing: 8 * scale,
                children: <Widget>[
                  for (final String label in labels)
                    Chip(
                      label: Text(label),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => onRemove(label),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 저장된 조합 상세 시트: 선택했던 카드, 수치, 수급자의견, 저장된 결과
// 문장을 보여준다. 단어 칩을 탭하면 시트가 닫히고 그 조합이 그대로
// 불러와진다. 문장을 탭하면 복사되고, 이름을 길게 누르면 전체 삭제한다.
class _SavedCombinationSheet extends StatelessWidget {
  const _SavedCombinationSheet({
    required this.combination,
    required this.labelOf,
    required this.onLoad,
    required this.onDelete,
  });

  final SavedCardCombination combination;
  final String Function(String key) labelOf;
  final VoidCallback onLoad;
  final Future<void> Function() onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('저장 삭제'),
            content: Text('"${combination.name}"을(를) 삭제할까요?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await onDelete();
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('복사되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            onLongPress: () => _confirmDelete(context),
            child: Text(
              combination.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kCardTitleColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '이름을 길게 누르면 전체 삭제',
            style: TextStyle(fontSize: 11, color: kSubHeaderColor),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final String key in combination.selectedKeys)
                        Chip(label: Text(labelOf(key))),
                    ],
                  ),
                  if (combination.opinion.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      '수급자·보호자 의견: ${combination.opinion}',
                      style: const TextStyle(color: kSubHeaderColor),
                    ),
                  ],
                  const SizedBox(height: 16),
                  for (final SavedResultEntry result in combination.results)
                    if (result.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _copy(context, result.text),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kPanelBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kCardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '[${result.label}] (탭해서 복사)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: kSubHeaderColor,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  result.text,
                                  style: const TextStyle(
                                    color: kCardTitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onLoad,
              child: const Text('이 조합 불러오기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpinionSection extends StatelessWidget {
  const _OpinionSection({required this.controller, required this.scale});

  final TextEditingController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 12 * scale),
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '수급자·보호자 의견 (선택)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: kCardTitleColor,
            ),
          ),
          SizedBox(height: 8 * scale),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '예) 허리가 아파서 화장실 가기가 무섭다고 하심',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: kCardBorder),
              ),
            ),
          ),
          SizedBox(height: 6 * scale),
          const Text(
            '어르신이나 보호자가 직접 하신 말씀을 적어주세요',
            style: TextStyle(color: kSubHeaderColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

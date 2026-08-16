import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/record_category.dart';
import '../models/saved_name_group.dart';
import '../models/word_combination_entry.dart';
import '../services/ai_record_api.dart';
import '../services/auto_log_repository.dart';
import '../services/custom_button_repository.dart';
import '../services/interstitial_ad_service.dart';
import '../services/saved_name_group_repository.dart';
import '../theme/pastel_palette.dart';
import '../utils/date_format.dart';
import '../utils/hangul_search.dart';
import '../widgets/ai_generating_dialog.dart';
import '../widgets/category_card.dart';
import '../widgets/my_saved_names_bar.dart';
import '../widgets/section_header.dart';
import '../widgets/selected_summary_bar.dart';
import '../widgets/word_search_section.dart';
import '../widgets/word_selection_panel.dart';
import 'ai_result_screen.dart';
import 'auto_log_screen.dart';
import 'my_saved_screen.dart';

// [전면개편] 카드 아래 단어 선택 영역이 펼쳐지고/접히는 AnimatedSize 애니메이션
// 길이. 카드를 전환할 때 스크롤 목표 위치 계산도 이 값을 기준으로 기다린다.
const Duration _kPanelAnimationDuration = Duration(milliseconds: 220);

/// [02][전면개편] 기록작성화면: 대분류(섹션) → 카드형 소분류 → 단어 선택
/// 영역의 3단계 구조로 방문 기록을 작성하는 화면.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final CustomButtonRepository _repository = CustomButtonRepository();
  // [저장개편] 자동 로그 / 내 저장 목록 저장소.
  final AutoLogRepository _autoLogRepository = AutoLogRepository();
  final SavedNameGroupRepository _savedNameGroupRepository =
      SavedNameGroupRepository();
  // [07] 백엔드 /generate 호출 클라이언트.
  final AiRecordApi _aiRecordApi = const AiRecordApi();
  // [AdMob] AI 문장 생성 로딩 중에 보여줄 전면광고.
  final InterstitialAdService _interstitialAdService = InterstitialAdService();

  // 세부 카테고리 id별 커스텀 버튼 목록. [02-04]
  Map<String, List<String>> _customButtons = <String, List<String>>{};
  // [저장개편] AI 문장 생성마다 자동으로 쌓이는 로그. 7일 지난 항목은 앱
  // 시작 시 걸러낸다.
  List<WordCombinationEntry> _autoLog = <WordCombinationEntry>[];
  // [저장개편] 사용자가 이름을 붙여 만든 "내 저장" 그룹 목록. 자동 삭제되지 않는다.
  List<SavedNameGroup> _savedNameGroups = <SavedNameGroup>[];
  // 세부 카테고리 id별 선택된 버튼 라벨 집합.
  final Map<String, Set<String>> _selectedButtons = <String, Set<String>>{
    for (final RecordCategory category in recordCategories)
      for (final RecordSubCategory subCategory in category.subCategories)
        subCategory.id: <String>{},
  };
  // 카테고리 id별 기타 직접입력 컨트롤러. [02-03]
  final Map<String, TextEditingController> _otherTextControllers =
      <String, TextEditingController>{
    for (final RecordCategory category in recordCategories)
      category.id: TextEditingController(),
  };
  // [B] 단어 검색 입력 컨트롤러.
  final TextEditingController _searchController = TextEditingController();

  // [전면개편] 현재 펼쳐진 카드 id. 한 번에 하나만 펼쳐진다.
  String? _expandedCategoryId;
  // [전면개편] 카드별 위젯 키. 검색/안내 팝업에서 특정 카드로 스크롤할 때 쓴다.
  final Map<String, GlobalKey> _categoryKeys = <String, GlobalKey>{
    for (final RecordCategory category in recordCategories)
      category.id: GlobalKey(),
  };
  // [전면개편] 카테고리 목록 스크롤 컨트롤러. "위로 가기" 버튼에도 쓴다.
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomButtons();
    _loadAutoLog();
    _loadSavedNameGroups();
    // [AdMob] 화면 진입 시 전면광고를 미리 불러와 둔다.
    _interstitialAdService.preload();
    // [B] 검색어가 바뀔 때마다 검색 결과 영역을 다시 그린다.
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    for (final TextEditingController controller
        in _otherTextControllers.values) {
      controller.dispose();
    }
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _scrollController.dispose();
    _interstitialAdService.dispose();
    super.dispose();
  }

  // 저장된 커스텀 버튼 목록을 불러와 상태를 갱신한다.
  Future<void> _loadCustomButtons() async {
    final customButtons = await _repository.load();
    if (!mounted) return;
    setState(() {
      _customButtons = customButtons;
      _isLoading = false;
    });
  }

  // [저장개편] 자동 로그를 불러오고, 7일이 지난 기록은 걸러내 다시 저장한다.
  Future<void> _loadAutoLog() async {
    final List<WordCombinationEntry> entries = await _autoLogRepository.load();
    final DateTime cutoff = DateTime.now().subtract(const Duration(days: 7));
    final List<WordCombinationEntry> fresh = entries
        .where((WordCombinationEntry e) => e.timestamp.isAfter(cutoff))
        .toList();
    if (fresh.length != entries.length) {
      await _autoLogRepository.save(fresh);
    }
    if (!mounted) return;
    setState(() => _autoLog = fresh);
  }

  // [저장개편] "내 저장" 이름 그룹 목록을 불러와 상태를 갱신한다.
  Future<void> _loadSavedNameGroups() async {
    final List<SavedNameGroup> groups = await _savedNameGroupRepository.load();
    if (!mounted) return;
    setState(() => _savedNameGroups = groups);
  }

  // [저장개편] 자동 로그를 최신순으로 정렬해 반환한다.
  List<WordCombinationEntry> get _autoLogSortedByRecent {
    final List<WordCombinationEntry> sorted = <WordCombinationEntry>[..._autoLog];
    sorted.sort(
      (WordCombinationEntry a, WordCombinationEntry b) =>
          b.timestamp.compareTo(a.timestamp),
    );
    return sorted;
  }

  // [저장개편] "내 저장" 그룹을 각 그룹의 최근 저장 시각 기준으로 정렬해 반환한다.
  List<SavedNameGroup> get _savedNameGroupsSortedByRecent {
    final List<SavedNameGroup> sorted = <SavedNameGroup>[..._savedNameGroups];
    sorted.sort(
      (SavedNameGroup a, SavedNameGroup b) =>
          b.lastSavedAt.compareTo(a.lastSavedAt),
    );
    return sorted;
  }

  // 현재 선택 상태를 세부 카테고리 id별 라벨 목록 스냅샷으로 만든다.
  Map<String, List<String>> _currentSelectionSnapshot() {
    return <String, List<String>>{
      for (final MapEntry<String, Set<String>> entry in _selectedButtons.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
    };
  }

  // [저장개편] 선택 조합 스냅샷을 기존 선택 항목 자리에 그대로 적용한다.
  // 자동 로그/내 저장 목록에서 단어 조합을 탭했을 때 공통으로 쓴다.
  void _applyCombinationSelection(
    Map<String, List<String>> selectedLabelsBySubCategoryId,
  ) {
    setState(() {
      for (final Set<String> selected in _selectedButtons.values) {
        selected.clear();
      }
      selectedLabelsBySubCategoryId.forEach(
        (String subCategoryId, List<String> labels) {
          final selected = _selectedButtons[subCategoryId];
          if (selected != null) {
            selected.addAll(labels);
          }
        },
      );
    });
  }

  // [저장개편] AI 문장 생성마다 자동으로 로그 맨 앞에 기록을 추가한다.
  Future<void> _appendAutoLogEntry(
    Map<String, List<String>> selectedLabelsBySubCategoryId,
    String generatedText,
  ) async {
    final WordCombinationEntry entry = WordCombinationEntry(
      timestamp: DateTime.now(),
      selectedLabelsBySubCategoryId: selectedLabelsBySubCategoryId,
      generatedText: generatedText,
    );
    setState(() {
      _autoLog = <WordCombinationEntry>[entry, ..._autoLog];
    });
    await _autoLogRepository.save(_autoLog);
  }

  // [저장개편] 이름에 기록을 추가한다. 같은 이름의 그룹이 있으면 이어붙이고,
  // 없으면 새 그룹을 만든다("저장" 팝업에서 새 이름/기존 이름 모두 이 경로를 탄다).
  Future<void> _appendToNameGroup(
    String name,
    Map<String, List<String>> selectedLabelsBySubCategoryId,
    String generatedText,
  ) async {
    final WordCombinationEntry entry = WordCombinationEntry(
      timestamp: DateTime.now(),
      selectedLabelsBySubCategoryId: selectedLabelsBySubCategoryId,
      generatedText: generatedText,
    );
    setState(() {
      final int index =
          _savedNameGroups.indexWhere((SavedNameGroup g) => g.name == name);
      if (index == -1) {
        _savedNameGroups = <SavedNameGroup>[
          ..._savedNameGroups,
          SavedNameGroup(name: name, entries: <WordCombinationEntry>[entry]),
        ];
      } else {
        final SavedNameGroup group = _savedNameGroups[index];
        _savedNameGroups = <SavedNameGroup>[..._savedNameGroups]
          ..[index] = SavedNameGroup(
            name: group.name,
            entries: <WordCombinationEntry>[...group.entries, entry],
          );
      }
    });
    await _savedNameGroupRepository.save(_savedNameGroups);
  }

  // [저장개편] 이름 그룹 안의 기록 하나를 삭제한다. 마지막 기록이 지워지면
  // 그룹 자체도 함께 사라진다.
  Future<void> _deleteNameGroupEntry(
      String name, WordCombinationEntry entry) async {
    setState(() {
      final int index =
          _savedNameGroups.indexWhere((SavedNameGroup g) => g.name == name);
      if (index == -1) return;
      final SavedNameGroup group = _savedNameGroups[index];
      final List<WordCombinationEntry> remaining = group.entries
          .where((WordCombinationEntry e) => !identical(e, entry))
          .toList();
      if (remaining.isEmpty) {
        _savedNameGroups = <SavedNameGroup>[..._savedNameGroups]
          ..removeAt(index);
      } else {
        _savedNameGroups = <SavedNameGroup>[..._savedNameGroups]
          ..[index] = SavedNameGroup(name: group.name, entries: remaining);
      }
    });
    await _savedNameGroupRepository.save(_savedNameGroups);
  }

  // [저장개편] 이름 그룹 전체(그 이름의 모든 기록)를 삭제한다.
  Future<void> _deleteNameGroup(String name) async {
    setState(() {
      _savedNameGroups =
          _savedNameGroups.where((SavedNameGroup g) => g.name != name).toList();
    });
    await _savedNameGroupRepository.save(_savedNameGroups);
  }

  // [저장개편] 이름을 탭하면 그 이름으로 저장된 기록들을 최근순으로 보여주는
  // 시트를 띄운다. 단어 조합을 탭하면 시트가 닫히고 메인 화면에 그 조합이
  // 선택되며, 문장을 탭하면 클립보드로 복사된다. 기록을 길게 누르면 개별
  // 삭제, 이름을 길게 누르면 전체 삭제를 할 수 있다.
  Future<void> _showNameRecordsSheet(String name) async {
    final SavedNameGroup? group = _savedNameGroups
        .where((SavedNameGroup g) => g.name == name)
        .cast<SavedNameGroup?>()
        .firstOrNull;
    if (group == null) return;

    final List<WordCombinationEntry> sortedEntries =
        <WordCombinationEntry>[...group.entries]
          ..sort((WordCombinationEntry a, WordCombinationEntry b) =>
              b.timestamp.compareTo(a.timestamp));

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: kAppBackground,
      builder: (BuildContext sheetContext) => _NameRecordsSheetContent(
        name: name,
        entries: sortedEntries,
        onDeleteEntry: (WordCombinationEntry entry) =>
            _deleteNameGroupEntry(name, entry),
        onDeleteGroup: () => _deleteNameGroup(name),
        onSelectCombination: (WordCombinationEntry entry) {
          _applyCombinationSelection(entry.selectedLabelsBySubCategoryId);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  // [저장개편] 화면 맨 아래 "기록 보기" 버튼: 자동 로그 화면으로 이동한다.
  Future<void> _openAutoLogScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AutoLogScreen(
          entries: _autoLogSortedByRecent,
          onSelectCombination: (WordCombinationEntry entry) {
            _applyCombinationSelection(entry.selectedLabelsBySubCategoryId);
            Navigator.of(this.context).pop();
          },
        ),
      ),
    );
  }

  // [저장개편] 화면 맨 아래 "내 저장" 버튼: 이름 목록 화면으로 이동한다.
  // 이름을 탭해 화면이 닫히면 그 이름의 기록 목록 시트를 이어서 띄운다.
  Future<void> _openMySavedScreen() async {
    final String? tappedName = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => MySavedScreen(
          groups: _savedNameGroupsSortedByRecent,
          onDeleteGroup: _deleteNameGroup,
        ),
      ),
    );
    if (tappedName != null && mounted) {
      await _showNameRecordsSheet(tappedName);
    }
  }

  // [D-A] 확인 팝업을 띄우고, 확인하면 선택된 항목을 전부 초기화한다.
  Future<void> _showResetConfirmDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('초기화'),
        content: const Text('선택 항목을 모두 초기화할까요?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      for (final Set<String> selected in _selectedButtons.values) {
        selected.clear();
      }
    });
  }

  // [06] 현재까지 선택된 버튼 총 개수. 카테고리를 가리지 않고 전체 합산한다.
  int get _totalSelectedCount =>
      _selectedButtons.values.fold(0, (int sum, Set<String> s) => sum + s.length);

  // 카테고리 하나 안에서 현재 선택된 버튼 개수(카드 배지 표시용).
  int _categorySelectedCount(RecordCategory category) {
    return category.subCategories.fold(
      0,
      (int sum, RecordSubCategory sub) =>
          sum + (_selectedButtons[sub.id]?.length ?? 0),
    );
  }

  // 버튼 선택 상태를 토글한다.
  void _toggleButton(RecordSubCategory subCategory, String label) {
    final selected = _selectedButtons[subCategory.id]!;
    if (selected.contains(label)) {
      setState(() => selected.remove(label));
      return;
    }
    _selectButtonRespectingCap(subCategory, label);
  }

  // [06] 아직 선택되지 않은 버튼을 선택 상태로 만든다. 전체 선택 개수가
  // kMaxSelectedButtons를 넘어가면 막고 안내 문구를 띄운 뒤 false를 반환한다.
  // [B] 검색 결과 탭, 직접입력 추가 등 "선택"만 필요한 곳에서 재사용한다.
  bool _selectButtonRespectingCap(RecordSubCategory subCategory, String label) {
    final selected = _selectedButtons[subCategory.id]!;
    if (selected.contains(label)) return true;

    if (_totalSelectedCount >= kMaxSelectedButtons) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 $kMaxSelectedButtons개까지 선택 가능합니다')),
      );
      return false;
    }

    setState(() => selected.add(label));
    return true;
  }

  // [전면개편] 카드를 펼치거나 접는다. 같은 카드를 다시 누르면 접는다.
  void _toggleCategoryExpand(String categoryId) {
    if (_expandedCategoryId == categoryId) {
      setState(() => _expandedCategoryId = null);
      return;
    }
    _expandAndScrollTo(categoryId);
  }

  // [전면개편] 카드를 펼치고, 화면을 그 카드 위치로 부드럽게 스크롤한다.
  // 이미 다른 카드가 펼쳐져 있던 경우에는 그 카드가 접히는 애니메이션이
  // 끝나 레이아웃이 완전히 자리잡을 때까지 기다린 뒤 스크롤 목표 위치를
  // 계산한다 - 그렇지 않으면 접힘/펼침 애니메이션이 동시에 진행되는 동안
  // 목표 위치가 계속 바뀌어 스크롤이 엉뚱한 곳으로 가거나 아예 안 움직이는
  // 것처럼 보인다.
  void _expandAndScrollTo(String categoryId) {
    final bool wasSwitchingFromAnotherCard =
        _expandedCategoryId != null && _expandedCategoryId != categoryId;
    setState(() => _expandedCategoryId = categoryId);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (wasSwitchingFromAnotherCard) {
        await Future<void>.delayed(_kPanelAnimationDuration);
      }
      if (!mounted || _expandedCategoryId != categoryId) return;
      final BuildContext? cardContext = _categoryKeys[categoryId]?.currentContext;
      if (cardContext == null || !cardContext.mounted) return;
      Scrollable.ensureVisible(
        cardContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    });
  }

  // [전면개편] "위로 가기" 버튼: 카테고리 목록을 맨 위로 부드럽게 스크롤한다.
  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // 새 커스텀 버튼을 추가할 문구를 입력받는 다이얼로그를 띄운다.
  Future<void> _showAddButtonDialog(RecordSubCategory subCategory) async {
    final label = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _AddButtonDialog(),
    );
    if (label == null || label.isEmpty) return;
    await _addCustomButton(subCategory, label);
  }

  // 커스텀 버튼을 세부 카테고리에 추가하고 저장한다. 이미 있는 버튼이면 안내만 하고 끝낸다.
  Future<void> _addCustomButton(
      RecordSubCategory subCategory, String label) async {
    final preset = subCategory.presetButtons;
    final custom = _customButtons[subCategory.id] ?? const <String>[];
    if (preset.contains(label) || custom.contains(label)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 있는 버튼입니다.')),
      );
      return;
    }

    setState(() {
      _customButtons = <String, List<String>>{
        ..._customButtons,
        subCategory.id: <String>[...custom, label],
      };
    });
    await _repository.save(_customButtons);
  }

  // 커스텀 버튼을 세부 카테고리에서 삭제하고 저장한다.
  Future<void> _deleteCustomButton(
      RecordSubCategory subCategory, String label) async {
    final custom = _customButtons[subCategory.id] ?? const <String>[];

    setState(() {
      _customButtons = <String, List<String>>{
        ..._customButtons,
        subCategory.id: <String>[...custom]..remove(label),
      };
      _selectedButtons[subCategory.id]!.remove(label);
    });
    await _repository.save(_customButtons);
  }

  // [B] 검색어와 일치하는 (카테고리, 세부 카테고리, 라벨)을 recordCategories
  // 순서대로 모은다. 기본 제공 버튼과 사용자가 추가한 커스텀 버튼을 모두 검색한다.
  List<WordSearchResult> _searchResults(String query) {
    if (query.trim().isEmpty) return const <WordSearchResult>[];

    final List<WordSearchResult> results = <WordSearchResult>[];
    for (final RecordCategory category in recordCategories) {
      for (final RecordSubCategory subCategory in category.subCategories) {
        final List<String> custom =
            _customButtons[subCategory.id] ?? const <String>[];
        for (final String label in <String>[
          ...subCategory.presetButtons,
          ...custom,
        ]) {
          if (matchesSearchQuery(label, query)) {
            results.add(
              (category: category, subCategory: subCategory, label: label),
            );
          }
        }
      }
    }
    return results;
  }

  // [B] 검색 결과를 탭하면 즉시 선택하고, 해당 카테고리를 펼친 뒤 검색창을 비운다.
  void _handleSearchResultTap(WordSearchResult result) {
    final bool added =
        _selectButtonRespectingCap(result.subCategory, result.label);
    if (!added) return;
    _expandAndScrollTo(result.category.id);
    _searchController.clear();
  }

  // [B] 검색 결과가 없을 때 "직접입력"으로 추가할 카테고리를 고르게 한 뒤,
  // 그 카테고리의 첫 세부 카테고리에 커스텀 버튼으로 추가하고 바로 선택한다.
  Future<void> _handleAddCustomWordFromSearch(String query) async {
    final RecordCategory? category = await showDialog<RecordCategory>(
      context: context,
      builder: (BuildContext context) => _PickCategoryDialog(word: query),
    );
    if (category == null || !mounted) return;

    final RecordSubCategory subCategory = category.subCategories.first;
    await _addCustomButton(subCategory, query);
    if (!mounted) return;

    _selectButtonRespectingCap(subCategory, query);
    _expandAndScrollTo(category.id);
    _searchController.clear();
  }

  // [02-03] 카테고리 순서대로, 현재 선택된 (세부 카테고리, 라벨) 쌍을 모두 모은다.
  List<SelectedButtonEntry> _selectedEntries() {
    return <SelectedButtonEntry>[
      for (final RecordCategory category in recordCategories)
        for (final RecordSubCategory subCategory in category.subCategories)
          for (final String label
              in _selectedButtons[subCategory.id] ?? const <String>{})
            (subCategory: subCategory, label: label),
    ];
  }

  // 카테고리 순서대로, 비어있지 않은 기타 직접입력 내용을 모은다.
  List<String> _otherTexts() {
    return <String>[
      for (final RecordCategory category in recordCategories)
        if (_otherTextControllers[category.id]!.text.trim().isNotEmpty)
          _otherTextControllers[category.id]!.text.trim(),
    ];
  }

  // [07] 카테고리 이름을 키로, 선택된 라벨 목록을 값으로 하는 selections 맵을
  // 만든다. 선택된 항목이 없는 카테고리는 키 자체를 넣지 않는다.
  Map<String, List<String>> _buildSelectionsByCategory() {
    final Map<String, List<String>> selections = <String, List<String>>{};
    for (final RecordCategory category in recordCategories) {
      final List<String> labels = <String>[
        for (final RecordSubCategory subCategory in category.subCategories)
          ...(_selectedButtons[subCategory.id] ?? const <String>{}),
      ];
      if (labels.isNotEmpty) {
        selections[category.name] = labels;
      }
    }
    return selections;
  }

  // [06] 선택된 항목 중 "조치·대응" 카드가 하나라도 있는지 확인한다.
  bool _hasActionCategorySelection(List<SelectedButtonEntry> entries) {
    return entries.any((SelectedButtonEntry entry) {
      final String categoryId = entry.subCategory.id.split('_sub_').first;
      return kActionCategoryIds.contains(categoryId);
    });
  }

  // [06][D-B] "조치·대응" 카드가 하나도 선택되지 않았으면 안내 팝업을 띄운다.
  // "선택하러 가기"를 고르면 그 카드로 스크롤/펼치기만 하고 생성은 하지
  // 않으며(false 반환), "계속 진행"을 고르면 그대로 생성을 이어간다(true 반환).
  Future<bool> _showActionCategoryHintIfNeeded(
      List<SelectedButtonEntry> entries) async {
    if (_hasActionCategorySelection(entries)) return true;

    final bool goSelect = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => AlertDialog(
            content: const Text(
              '💡 "조치·대응" 카드도 함께 선택하면 더 완성도 높은 기록이 생성됩니다',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('선택하러 가기'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('계속 진행'),
              ),
            ],
          ),
        ) ??
        false;

    if (goSelect) {
      _expandAndScrollTo(kActionHintTargetCategoryId);
      return false;
    }
    return true;
  }

  Future<void> _generateAiRecord() async {
    final List<SelectedButtonEntry> entries = _selectedEntries();
    final bool shouldProceed = await _showActionCategoryHintIfNeeded(entries);
    if (!shouldProceed || !mounted) return;

    final Map<String, List<String>> selections = _buildSelectionsByCategory();
    final List<String> otherTexts = _otherTexts();
    if (otherTexts.isNotEmpty) {
      selections['기타'] = otherTexts;
    }
    // [전면개편-5] AI 결과 화면에서 "저장"을 누를 때 함께 저장할 선택 조합
    // 스냅샷. 그 사이 사용자가 선택을 바꿀 수 있으니 지금 시점 것을 고정해둔다.
    final Map<String, List<String>> selectionSnapshot =
        _currentSelectionSnapshot();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const AiGeneratingDialog(),
    );

    // [AdMob] 로딩 스피너를 띄운 채로 생성 요청을 먼저 시작해두고, 그 사이
    // 미리 불러온 전면광고가 있으면 보여준다(광고를 보는 동안 백그라운드에서
    // 생성이 계속 진행된다). 광고가 없거나 로드/표시에 실패해도 생성 흐름은
    // 그대로 이어간다.
    final Future<String> generateFuture = _aiRecordApi.generate(selections);
    await _interstitialAdService.showIfReady();

    String generatedText;
    try {
      generatedText = await generateFuture;
    } on AiRecordApiException catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

    // [저장개편] 생성될 때마다 자동으로 로그에 남긴다(사용자가 따로 저장하지
    // 않아도 항상 쌓인다).
    await _appendAutoLogEntry(selectionSnapshot, generatedText);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AiResultScreen(
          initialText: generatedText,
          onSave: (String text) async {
            final String? name = await showDialog<String>(
              context: this.context,
              builder: (BuildContext context) => _SaveToNameDialog(
                existingNames: <String>[
                  for (final SavedNameGroup g in _savedNameGroupsSortedByRecent)
                    g.name,
                ],
              ),
            );
            if (name == null || name.isEmpty) return false;
            await _appendToNameGroup(name, selectionSnapshot, text);
            return true;
          },
        ),
      ),
    );
  }

  // [전면개편] 대분류 하나를 헤더 + 카드 3열 그리드 + (펼쳐졌다면) 단어 선택
  // 영역으로 그린다.
  Widget _buildSection(RecordSection section) {
    final List<Widget> rows = <Widget>[SectionHeader(title: section.name)];

    for (int i = 0; i < section.categories.length; i += 3) {
      final List<RecordCategory> chunk = section.categories.sublist(
        i,
        (i + 3) > section.categories.length ? section.categories.length : i + 3,
      );

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int j = 0; j < 3; j++) ...<Widget>[
                if (j > 0) const SizedBox(width: 10),
                Expanded(
                  child: j < chunk.length
                      ? KeyedSubtree(
                          key: _categoryKeys[chunk[j].id],
                          child: CategoryCard(
                            category: chunk[j],
                            expanded: _expandedCategoryId == chunk[j].id,
                            badgeCount: _categorySelectedCount(chunk[j]),
                            onTap: () => _toggleCategoryExpand(chunk[j].id),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );

      final RecordCategory? expandedInChunk = chunk
          .where((RecordCategory c) => c.id == _expandedCategoryId)
          .cast<RecordCategory?>()
          .firstOrNull;

      rows.add(
        AnimatedSize(
          duration: _kPanelAnimationDuration,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expandedInChunk == null
              ? const SizedBox(width: double.infinity)
              : WordSelectionPanel(
                  category: expandedInChunk,
                  customButtonsBySubCategory: _customButtons,
                  selectedButtonsBySubCategory: _selectedButtons,
                  otherTextController: _otherTextControllers[expandedInChunk.id]!,
                  onToggleButton: _toggleButton,
                  onAddButton: _showAddButtonDialog,
                  onDeleteButton: _deleteCustomButton,
                  onScrollToTop: _scrollToTop,
                ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final List<SelectedButtonEntry> selectedEntries = _selectedEntries();
    final bool canGenerate =
        selectedEntries.isNotEmpty || _otherTexts().isNotEmpty;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('기록 작성'),
        centerTitle: false,
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                // [저장개편] "내 저장" 이름 목록을 화면 최상단에 최근 저장순
                // 가로 스크롤로 항상 표시한다.
                MySavedNamesBar(
                  groups: _savedNameGroupsSortedByRecent,
                  onTapName: _showNameRecordsSheet,
                ),
                // [B] 카드 목록 상단에 고정된 단어 검색창 + 검색 결과.
                WordSearchSection(
                  controller: _searchController,
                  results: _searchResults(_searchController.text),
                  onResultTap: _handleSearchResultTap,
                  onAddCustomWord: _handleAddCustomWordFromSearch,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final RecordSection section in recordSections)
                          _buildSection(section),
                      ],
                    ),
                  ),
                ),
                // [02-03][저장개편] 선택된 버튼을 화면 하단에 고정 표시하고,
                // 그 아래 AI 기록 생성 버튼과 기록 보기/내 저장 진입 버튼을 둔다.
                SelectedSummaryBar(
                  selectedEntries: selectedEntries,
                  canGenerate: canGenerate,
                  onRemove: _toggleButton,
                  onGenerate: _generateAiRecord,
                  onReset: selectedEntries.isEmpty
                      ? null
                      : _showResetConfirmDialog,
                  onViewAutoLog: _openAutoLogScreen,
                  onViewMySaved: _openMySavedScreen,
                ),
              ],
            ),
    );
  }
}

// [02-04] 버튼 추가 다이얼로그. 입력 컨트롤러를 자체적으로 소유/해제해 다이얼로그가
// 닫히는 애니메이션 도중 컨트롤러가 먼저 dispose되는 문제를 피한다.
class _AddButtonDialog extends StatefulWidget {
  const _AddButtonDialog();

  @override
  State<_AddButtonDialog> createState() => _AddButtonDialogState();
}

class _AddButtonDialogState extends State<_AddButtonDialog> {
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
        decoration: const InputDecoration(hintText: '버튼에 표시할 문구'),
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

// [B] 검색 결과가 없을 때 "직접입력"으로 추가할 카테고리를 고르는 다이얼로그.
class _PickCategoryDialog extends StatelessWidget {
  const _PickCategoryDialog({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('"$word"을(를) 추가할 카테고리'),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final RecordCategory category in recordCategories)
              ListTile(
                leading: Text(category.emoji, style: const TextStyle(fontSize: 20)),
                title: Text(category.name),
                onTap: () => Navigator.of(context).pop(category),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

// [저장개편] "저장" 팝업: 새 이름 입력창 + 저장 버튼, 그 아래 기존에 저장된
// 이름 목록. 새 이름을 입력해 저장하거나 기존 이름을 탭하면 그 이름으로
// (신규 생성 또는 이어붙이기) 저장할 이름을 pop으로 반환한다.
class _SaveToNameDialog extends StatefulWidget {
  const _SaveToNameDialog({required this.existingNames});

  // 최근 저장순으로 정렬되어 전달된다.
  final List<String> existingNames;

  @override
  State<_SaveToNameDialog> createState() => _SaveToNameDialogState();
}

class _SaveToNameDialogState extends State<_SaveToNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitNewName() {
    final String name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('저장'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration:
                        const InputDecoration(hintText: '새 이름 입력 (예: 김할머니)'),
                    onSubmitted: (_) => _submitNewName(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submitNewName,
                  child: const Text('저장'),
                ),
              ],
            ),
            if (widget.existingNames.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              const Text(
                '기존 이름에 추가 저장',
                style: TextStyle(fontWeight: FontWeight.w700, color: kSubHeaderColor),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.existingNames.length,
                  itemBuilder: (BuildContext context, int index) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(widget.existingNames[index]),
                    onTap: () =>
                        Navigator.of(context).pop(widget.existingNames[index]),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

// [저장개편] 이름 하나에 저장된 기록들을 최근순으로 보여주는 시트 본문.
// 단어 조합을 탭하면 메인 화면에 선택되며 시트가 닫히고, 문장을 탭하면
// 클립보드로 복사된다. 기록을 길게 누르면 개별 삭제, 이름 제목을 길게
// 누르면 그 이름의 기록 전체를 삭제한다.
class _NameRecordsSheetContent extends StatefulWidget {
  const _NameRecordsSheetContent({
    required this.name,
    required this.entries,
    required this.onDeleteEntry,
    required this.onDeleteGroup,
    required this.onSelectCombination,
  });

  final String name;
  // 최근순으로 정렬되어 전달된다.
  final List<WordCombinationEntry> entries;
  final Future<void> Function(WordCombinationEntry entry) onDeleteEntry;
  final Future<void> Function() onDeleteGroup;
  final void Function(WordCombinationEntry entry) onSelectCombination;

  @override
  State<_NameRecordsSheetContent> createState() =>
      _NameRecordsSheetContentState();
}

class _NameRecordsSheetContentState extends State<_NameRecordsSheetContent> {
  late List<WordCombinationEntry> _entries = widget.entries;

  Future<void> _confirmDeleteGroup() async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('저장 목록 삭제'),
            content: Text('"${widget.name}"의 저장된 기록을 모두 삭제할까요?'),
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
    if (!confirmed || !mounted) return;
    await widget.onDeleteGroup();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _confirmDeleteEntry(WordCombinationEntry entry) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('기록 삭제'),
            content: const Text('이 기록을 삭제할까요?'),
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
    if (!confirmed || !mounted) return;
    await widget.onDeleteEntry(entry);
    if (!mounted) return;
    setState(() {
      _entries =
          _entries.where((WordCombinationEntry e) => !identical(e, entry)).toList();
    });
    if (_entries.isEmpty && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('복사되었습니다.')),
    );
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
            onLongPress: _confirmDeleteGroup,
            child: Text(
              widget.name,
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
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _entries.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(height: 24),
              itemBuilder: (BuildContext context, int index) {
                final WordCombinationEntry entry = _entries[index];
                return GestureDetector(
                  onLongPress: () => _confirmDeleteEntry(entry),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        formatDateTime(entry.timestamp),
                        style: const TextStyle(
                          color: kSubHeaderColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if (entry.words.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => widget.onSelectCombination(entry),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              for (final String word in entry.words)
                                Chip(
                                  label: Text(word),
                                  backgroundColor: kWordButtonBg,
                                  labelStyle:
                                      const TextStyle(color: kWordButtonText),
                                  side: BorderSide.none,
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _copy(entry.generatedText),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kPanelBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kCardBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  entry.generatedText,
                                  style: const TextStyle(color: kCardTitleColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy, size: 18, color: kAccentPurple),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

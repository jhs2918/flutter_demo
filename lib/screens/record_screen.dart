import 'package:flutter/material.dart';

import '../models/record_category.dart';
import '../models/saved_word_combination.dart';
import '../services/ai_record_api.dart';
import '../services/custom_button_repository.dart';
import '../services/saved_word_combination_repository.dart';
import '../widgets/ai_generating_dialog.dart';
import '../widgets/category_accordion_tile.dart';
import '../widgets/saved_combination_bar.dart';
import '../widgets/selected_summary_bar.dart';
import 'ai_result_screen.dart';

/// [02] 기록작성화면: 19개 카테고리를 아코디언으로 펼쳐 버튼을 선택해 방문 기록을 작성하는 화면.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final CustomButtonRepository _repository = CustomButtonRepository();
  // [02-10] 저장된 단어 조합 저장소.
  final SavedWordCombinationRepository _savedCombinationRepository =
      SavedWordCombinationRepository();
  // [07] 백엔드 /generate 호출 클라이언트.
  final AiRecordApi _aiRecordApi = const AiRecordApi();

  // 세부 카테고리 id별 커스텀 버튼 목록. [02-04]
  Map<String, List<String>> _customButtons = <String, List<String>>{};
  // [02-10] 저장된 단어 조합 목록. 목록 순서 = 화면에 표시할 번호.
  List<SavedWordCombination> _savedCombinations = <SavedWordCombination>[];
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

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomButtons();
    _loadSavedCombinations();
  }

  @override
  void dispose() {
    for (final TextEditingController controller
        in _otherTextControllers.values) {
      controller.dispose();
    }
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

  // [02-10] 저장된 단어 조합 목록을 불러와 상태를 갱신한다.
  Future<void> _loadSavedCombinations() async {
    final savedCombinations = await _savedCombinationRepository.load();
    if (!mounted) return;
    setState(() {
      _savedCombinations = savedCombinations;
    });
  }

  // [02-10] 이름 입력 팝업을 띄우고, 이름이 입력되면 현재 선택된 단어 조합을 저장한다.
  Future<void> _showSaveCombinationDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _SaveCombinationDialog(),
    );
    if (name == null || name.isEmpty) return;
    await _saveCurrentCombination(name);
  }

  // [02-10] 현재 선택된 단어 조합을 목록 맨 뒤에 추가하고 저장한다.
  Future<void> _saveCurrentCombination(String name) async {
    final selectedLabelsBySubCategoryId = <String, List<String>>{
      for (final MapEntry<String, Set<String>> entry
          in _selectedButtons.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
    };

    setState(() {
      _savedCombinations = <SavedWordCombination>[
        ..._savedCombinations,
        SavedWordCombination(
          name: name,
          selectedLabelsBySubCategoryId: selectedLabelsBySubCategoryId,
        ),
      ];
    });
    await _savedCombinationRepository.save(_savedCombinations);
  }

  // [02-10] 저장된 단어 조합을 불러와 기존 선택 항목을 대체한다.
  void _loadCombination(int index) {
    final combination = _savedCombinations[index];
    setState(() {
      for (final Set<String> selected in _selectedButtons.values) {
        selected.clear();
      }
      combination.selectedLabelsBySubCategoryId.forEach(
        (String subCategoryId, List<String> labels) {
          final selected = _selectedButtons[subCategoryId];
          if (selected != null) {
            selected.addAll(labels);
          }
        },
      );
    });
  }

  // [02-10] 삭제 확인 팝업을 띄우고, 확인하면 저장된 단어 조합을 삭제한다. 목록에서
  // 제거하는 것만으로 뒤 항목들의 표시 번호가 자동으로 재정렬된다.
  Future<void> _showDeleteCombinationDialog(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('저장 항목 삭제'),
        content: Text('"${_savedCombinations[index].name}"을(를) 삭제할까요?'),
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
    );
    if (confirmed != true) return;

    setState(() {
      _savedCombinations = <SavedWordCombination>[..._savedCombinations]
        ..removeAt(index);
    });
    await _savedCombinationRepository.save(_savedCombinations);
  }

  // [06] 현재까지 선택된 버튼 총 개수. 카테고리를 가리지 않고 전체 합산한다.
  int get _totalSelectedCount =>
      _selectedButtons.values.fold(0, (int sum, Set<String> s) => sum + s.length);

  // 버튼 선택 상태를 토글한다. [06] 전체 선택 개수가 kMaxSelectedButtons를
  // 넘어가는 추가 선택은 막고 안내 문구를 띄운다.
  void _toggleButton(RecordSubCategory subCategory, String label) {
    final selected = _selectedButtons[subCategory.id]!;
    final bool isSelected = selected.contains(label);

    if (!isSelected && _totalSelectedCount >= kMaxSelectedButtons) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 $kMaxSelectedButtons개까지 선택 가능합니다')),
      );
      return;
    }

    setState(() {
      if (isSelected) {
        selected.remove(label);
      } else {
        selected.add(label);
      }
    });
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

  // [06] 선택된 항목 중 ⑰~⑲(위생·청결/일상생활 지원/조치·대응) 카테고리가
  // 하나라도 있는지 확인한다.
  bool _hasActionCategorySelection(List<SelectedButtonEntry> entries) {
    return entries.any((SelectedButtonEntry entry) {
      final String categoryId = entry.subCategory.id.split('_sub_').first;
      return kActionCategoryIds.contains(categoryId);
    });
  }

  // [06] ⑰~⑲ 카테고리가 하나도 선택되지 않았으면 안내 팝업을 띄운다. 강제가
  // 아니므로 확인 버튼 하나만 두고, 닫히면 그대로 생성을 이어간다.
  Future<void> _showActionCategoryHintIfNeeded(
      List<SelectedButtonEntry> entries) async {
    if (_hasActionCategorySelection(entries)) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: const Text(
          '💡 ⑰~⑲ 조치 항목을 함께 선택하면 더 완성도 높은 기록이 생성됩니다',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAiRecord() async {
    final List<SelectedButtonEntry> entries = _selectedEntries();
    await _showActionCategoryHintIfNeeded(entries);
    if (!mounted) return;

    final Map<String, List<String>> selections = _buildSelectionsByCategory();
    final List<String> otherTexts = _otherTexts();
    if (otherTexts.isNotEmpty) {
      selections['기타'] = otherTexts;
    }

    // TODO: 전면광고 연동 시 이 로딩 다이얼로그 자리에 광고를 노출한다.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const AiGeneratingDialog(),
    );

    String generatedText;
    try {
      generatedText = await _aiRecordApi.generate(selections);
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

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            AiResultScreen(initialText: generatedText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<SelectedButtonEntry> selectedEntries = _selectedEntries();
    final bool canGenerate =
        selectedEntries.isNotEmpty || _otherTexts().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록 작성'),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                // [02-10] 저장된 단어 조합 목록을 화면 최상단에 가로 스크롤로 표시한다.
                SavedCombinationBar(
                  combinations: _savedCombinations,
                  onTap: _loadCombination,
                  onLongPress: _showDeleteCombinationDialog,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: <Widget>[
                      for (final RecordCategory category in recordCategories)
                        CategoryAccordionTile(
                          category: category,
                          customButtonsBySubCategory: _customButtons,
                          selectedButtonsBySubCategory: _selectedButtons,
                          otherTextController:
                              _otherTextControllers[category.id]!,
                          onToggleButton: _toggleButton,
                          onAddButton: _showAddButtonDialog,
                          onDeleteButton: _deleteCustomButton,
                        ),
                    ],
                  ),
                ),
                // [02-03] 선택된 버튼을 화면 하단에 고정 표시하고, 그 아래 AI 기록 생성
                // 버튼과 [02-10] 단어 조합 저장 버튼을 둔다.
                SelectedSummaryBar(
                  selectedEntries: selectedEntries,
                  canGenerate: canGenerate,
                  onRemove: _toggleButton,
                  onGenerate: _generateAiRecord,
                  onSave: selectedEntries.isEmpty
                      ? null
                      : _showSaveCombinationDialog,
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

// [02-10] 단어 조합 저장 이름 입력 다이얼로그. _AddButtonDialog와 같은 이유로
// 입력 컨트롤러를 자체적으로 소유/해제한다.
class _SaveCombinationDialog extends StatefulWidget {
  const _SaveCombinationDialog();

  @override
  State<_SaveCombinationDialog> createState() =>
      _SaveCombinationDialogState();
}

class _SaveCombinationDialogState extends State<_SaveCombinationDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('단어 조합 저장'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '저장할 이름 (예: 김할머니)'),
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

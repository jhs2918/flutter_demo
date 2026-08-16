import 'package:flutter/material.dart';

import '../models/record_category.dart';
import '../theme/pastel_palette.dart';

/// [전면개편] 카드 아래에 펼쳐지는 단어 선택 영역. 세부 그룹별 단어 버튼 +
/// 버튼 추가 + 기타 직접입력란 + "위로 가기" 버튼을 보여준다.
class WordSelectionPanel extends StatelessWidget {
  const WordSelectionPanel({
    super.key,
    required this.category,
    required this.customButtonsBySubCategory,
    required this.selectedButtonsBySubCategory,
    required this.otherTextController,
    required this.onToggleButton,
    required this.onAddButton,
    required this.onDeleteButton,
    required this.onScrollToTop,
  });

  final RecordCategory category;
  final Map<String, List<String>> customButtonsBySubCategory;
  final Map<String, Set<String>> selectedButtonsBySubCategory;
  final TextEditingController otherTextController;
  final void Function(RecordSubCategory subCategory, String label) onToggleButton;
  final ValueChanged<RecordSubCategory> onAddButton;
  final void Function(RecordSubCategory subCategory, String label) onDeleteButton;
  final VoidCallback onScrollToTop;

  Widget _buildWordChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    VoidCallback? onDeleted,
  }) {
    return FilterChip(
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? kWordButtonSelectedText : kWordButtonText,
        fontWeight: FontWeight.w600,
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: kWordButtonBg,
      selectedColor: kWordButtonSelectedBg,
      checkmarkColor: Colors.white,
      side: BorderSide.none,
      deleteIcon: onDeleted == null
          ? null
          : Icon(
              Icons.close,
              size: 18,
              color: selected ? Colors.white : kWordButtonText,
            ),
      onDeleted: onDeleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: kPanelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final RecordSubCategory subCategory in category.subCategories)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (subCategory.name.isNotEmpty) ...<Widget>[
                    Text(
                      subCategory.name,
                      style: const TextStyle(
                        color: kSubHeaderColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String label in subCategory.presetButtons)
                        _buildWordChip(
                          label: label,
                          selected: (selectedButtonsBySubCategory[subCategory.id] ??
                                  const <String>{})
                              .contains(label),
                          onSelected: () => onToggleButton(subCategory, label),
                        ),
                      for (final String label
                          in customButtonsBySubCategory[subCategory.id] ??
                              const <String>[])
                        _buildWordChip(
                          label: label,
                          selected: (selectedButtonsBySubCategory[subCategory.id] ??
                                  const <String>{})
                              .contains(label),
                          onSelected: () => onToggleButton(subCategory, label),
                          onDeleted: () => onDeleteButton(subCategory, label),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18, color: kWordButtonText),
                        label: const Text('버튼 추가', style: TextStyle(color: kWordButtonText)),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: kCardBorder),
                        onPressed: () => onAddButton(subCategory),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          TextField(
            controller: otherTextController,
            maxLines: 3,
            style: const TextStyle(color: kCardTitleColor),
            decoration: const InputDecoration(
              labelText: '기타 직접입력',
              hintText: '목록에 없는 내용을 직접 입력하세요',
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderSide: BorderSide(color: kCardBorder)),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: onScrollToTop,
              icon: const Icon(Icons.arrow_upward, size: 18, color: kAccentPurple),
              label: const Text('위로 가기', style: TextStyle(color: kAccentPurple)),
            ),
          ),
        ],
      ),
    );
  }
}

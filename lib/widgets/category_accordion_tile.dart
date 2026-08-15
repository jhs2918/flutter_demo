import 'package:flutter/material.dart';

import '../models/record_category.dart';

/// [02-01] 카테고리 아코디언 항목 하나: 클릭하면 펼쳐지며 세부 카테고리별
/// 버튼 목록 + 버튼 추가 + 기타 직접입력란을 보여준다.
class CategoryAccordionTile extends StatelessWidget {
  const CategoryAccordionTile({
    super.key,
    required this.category,
    required this.customButtonsBySubCategory,
    required this.selectedButtonsBySubCategory,
    required this.otherTextController,
    required this.onToggleButton,
    required this.onAddButton,
    required this.onDeleteButton,
  });

  final RecordCategory category;
  // [02-04] 세부 카테고리 id별 사용자가 추가한 커스텀 버튼. 삭제할 수 있다.
  final Map<String, List<String>> customButtonsBySubCategory;
  // 세부 카테고리 id별 현재 선택된 버튼 라벨 집합.
  final Map<String, Set<String>> selectedButtonsBySubCategory;
  final TextEditingController otherTextController;
  final void Function(RecordSubCategory subCategory, String label) onToggleButton;
  final ValueChanged<RecordSubCategory> onAddButton;
  final void Function(RecordSubCategory subCategory, String label) onDeleteButton;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          category.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final RecordSubCategory subCategory in category.subCategories)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 세부 카테고리 이름이 아직 없는 경우(카테고리 전체가 세부 카테고리
                  // 1개로 묶여 있는 상태) 헤더를 그리지 않는다.
                  if (subCategory.name.isNotEmpty) ...<Widget>[
                    Text(
                      subCategory.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String label in subCategory.presetButtons)
                        FilterChip(
                          label: Text(label),
                          selected: (selectedButtonsBySubCategory[subCategory.id] ??
                                  const <String>{})
                              .contains(label),
                          onSelected: (_) => onToggleButton(subCategory, label),
                        ),
                      for (final String label
                          in customButtonsBySubCategory[subCategory.id] ??
                              const <String>[])
                        FilterChip(
                          label: Text(label),
                          selected: (selectedButtonsBySubCategory[subCategory.id] ??
                                  const <String>{})
                              .contains(label),
                          onSelected: (_) => onToggleButton(subCategory, label),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => onDeleteButton(subCategory, label),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('버튼 추가'),
                        onPressed: () => onAddButton(subCategory),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // [02-03] 기타 직접입력란.
          TextField(
            controller: otherTextController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '기타 직접입력',
              hintText: '목록에 없는 내용을 직접 입력하세요',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

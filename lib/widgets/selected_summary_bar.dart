import 'package:flutter/material.dart';

import '../models/record_category.dart';

/// [02-03] 선택된 버튼 하나를 가리키는 (세부 카테고리, 라벨) 쌍.
typedef SelectedButtonEntry = ({RecordSubCategory subCategory, String label});

/// [02-03] 화면 하단에 고정되어 현재까지 선택된 버튼들을 칩으로 보여주고,
/// "AI 기록 생성" 버튼을 제공하는 요약 바.
class SelectedSummaryBar extends StatelessWidget {
  const SelectedSummaryBar({
    super.key,
    required this.selectedEntries,
    required this.canGenerate,
    required this.onRemove,
    required this.onGenerate,
    required this.onSave,
  });

  final List<SelectedButtonEntry> selectedEntries;
  // 선택된 버튼이 하나도 없어도 기타 직접입력이 있으면 생성할 수 있어, 이 값은
  // record_screen에서 별도로 계산해 전달한다.
  final bool canGenerate;
  final void Function(RecordSubCategory subCategory, String label) onRemove;
  final VoidCallback onGenerate;
  // [02-10] 선택된 버튼이 있을 때만 단어 조합을 저장할 수 있어 null이면 비활성화한다.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                // [06] 전체 카테고리 통틀어 최대 kMaxSelectedButtons개까지
                // 선택 가능해, 현재 개수를 "N/10" 형태의 카운터로 보여준다.
                '선택한 항목 (${selectedEntries.length}/$kMaxSelectedButtons)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 96),
                child: selectedEntries.isEmpty
                    ? Text(
                        '카테고리에서 버튼을 선택하면 여기에 표시됩니다.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final SelectedButtonEntry entry
                                in selectedEntries)
                              Chip(
                                label: Text(entry.label),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () =>
                                    onRemove(entry.subCategory, entry.label),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canGenerate ? onGenerate : null,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('AI 기록 생성'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onSave,
                    icon: const Text('💾'),
                    label: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

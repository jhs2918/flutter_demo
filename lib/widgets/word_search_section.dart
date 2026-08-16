import 'package:flutter/material.dart';

import '../models/record_category.dart';

/// [B] 검색 결과 하나: 어느 카테고리·세부 카테고리의 어떤 라벨인지를 가리킨다.
typedef WordSearchResult = ({
  RecordCategory category,
  RecordSubCategory subCategory,
  String label,
});

/// [B] 카테고리 아코디언 상단에 고정되는 단어 검색창과 검색 결과 영역.
/// 검색어가 비어 있으면 검색창만 보이고, 입력이 있으면 그 아래 결과(또는
/// 결과 없음 안내 + 직접입력 버튼)가 실시간으로 표시된다.
class WordSearchSection extends StatelessWidget {
  const WordSearchSection({
    super.key,
    required this.controller,
    required this.results,
    required this.onResultTap,
    required this.onAddCustomWord,
  });

  final TextEditingController controller;
  final List<WordSearchResult> results;
  final ValueChanged<WordSearchResult> onResultTap;
  final ValueChanged<String> onAddCustomWord;

  @override
  Widget build(BuildContext context) {
    final String query = controller.text.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              key: const Key('wordSearchField'),
              controller: controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                prefixIcon: const Icon(Icons.search),
                hintText: '단어 검색...',
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: controller.clear,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (query.isNotEmpty) _buildResultsArea(context, query),
        ],
      ),
    );
  }

  Widget _buildResultsArea(BuildContext context, String query) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '"$query" 검색결과 없음',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onAddCustomWord(query),
              icon: const Icon(Icons.add),
              label: Text('"$query" 직접입력으로 추가'),
            ),
          ],
        ),
      );
    }

    // 카테고리 순서(recordCategories 순서)를 유지하며 결과를 묶는다.
    final Map<RecordCategory, List<WordSearchResult>> grouped =
        <RecordCategory, List<WordSearchResult>>{};
    for (final WordSearchResult result in results) {
      (grouped[result.category] ??= <WordSearchResult>[]).add(result);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '"$query" 검색결과 ${results.length}개',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            for (final MapEntry<RecordCategory, List<WordSearchResult>> entry
                in grouped.entries) ...<Widget>[
              Text(
                entry.key.name,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final WordSearchResult result in entry.value)
                    ActionChip(
                      label: Text(result.label),
                      onPressed: () => onResultTap(result),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

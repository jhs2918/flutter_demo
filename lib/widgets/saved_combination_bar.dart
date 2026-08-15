import 'package:flutter/material.dart';

import '../models/saved_word_combination.dart';

/// [02-10] 화면 최상단에 저장된 단어 조합을 "번호.이름" 버튼으로 가로 스크롤
/// 표시하는 목록. 저장된 항목이 없으면 영역 자체를 숨긴다.
class SavedCombinationBar extends StatelessWidget {
  const SavedCombinationBar({
    super.key,
    required this.combinations,
    required this.onTap,
    required this.onLongPress,
  });

  final List<SavedWordCombination> combinations;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onLongPress;

  @override
  Widget build(BuildContext context) {
    if (combinations.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
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
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onTap(index),
              onLongPress: () => onLongPress(index),
              child: Chip(
                label: Text('${index + 1}.${combinations[index].name}'),
              ),
            );
          },
        ),
      ),
    );
  }
}

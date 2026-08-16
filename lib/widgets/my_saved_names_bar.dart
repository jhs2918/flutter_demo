import 'package:flutter/material.dart';

import '../models/saved_name_group.dart';
import '../theme/pastel_palette.dart';

/// [저장개편] 화면 최상단에 "내 저장" 이름 목록을 최근 저장순으로 가로
/// 스크롤 표시하는 바. 이름을 탭하면 그 이름의 기록 목록 팝업이 열린다.
/// 저장된 이름이 없으면 영역 자체를 숨긴다.
class MySavedNamesBar extends StatelessWidget {
  const MySavedNamesBar({
    super.key,
    required this.groups,
    required this.onTapName,
  });

  // 최근 저장순으로 정렬되어 전달된다.
  final List<SavedNameGroup> groups;
  final ValueChanged<String> onTapName;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

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
          itemCount: groups.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int index) {
            final SavedNameGroup group = groups[index];
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onTapName(group.name),
              child: Chip(
                avatar: const Icon(Icons.star, size: 16, color: kAccentPurple),
                label: Text(group.name),
                backgroundColor: kWordButtonBg,
                labelStyle: const TextStyle(color: kWordButtonText, fontWeight: FontWeight.w600),
                side: BorderSide.none,
              ),
            );
          },
        ),
      ),
    );
  }
}

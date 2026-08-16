import 'package:flutter/material.dart';

import '../models/record_category.dart';
import '../theme/pastel_palette.dart';

/// [전면개편] 대분류 안의 소분류 카드 하나. 3개씩 가로로 배열되며, 탭하면
/// 색이 바뀌고 살짝 커지는 애니메이션과 함께 선택 상태가 된다.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.expanded,
    required this.onTap,
    this.badgeCount = 0,
  });

  final RecordCategory category;
  final bool expanded;
  final VoidCallback onTap;
  // 이 카드 안에서 현재 선택된 단어 개수. 0이면 배지를 그리지 않는다.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: expanded ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: expanded ? kCardSelectedBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: expanded ? kCardSelectedBorder : kCardBorder,
            width: expanded ? 2 : 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Text(category.emoji, style: const TextStyle(fontSize: 26)),
                      if (badgeCount > 0)
                        Positioned(
                          right: -10,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kAccentPurple,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kCardTitleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

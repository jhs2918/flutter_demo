import 'package:flutter/material.dart';

import '../theme/pastel_palette.dart';

/// [전면개편] 대분류(섹션) 헤더. 파스텔 보라 배경에 굵은 흰 글씨로 섹션
/// 이름을 보여준다.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 20, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kSectionHeaderBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: kSectionHeaderText,
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

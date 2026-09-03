import 'package:flutter/material.dart';

import '../theme/pastel_palette.dart';

/// [수익화] 5,000원(premium_30) 구매자가 하루 30회를 다 쓴 뒤, 광고가 뜨기
/// 바로 직전에 딱 한 번만(설치 기준 평생 1회) 보여주는 9,900원 업그레이드
/// 안내. 호출부(card_select_screen)가 "이미 보여준 적 있는지"를 판단해서
/// 이 함수는 조건 없이 항상 뜬다.
Future<void> showUpgradePromptDialog(
  BuildContext context, {
  required VoidCallback onUpgrade,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('하루 100회로 늘려볼까요?'),
      content: const Text(
        '하루 100회 무료로 사용하려면\n9,900원 👉 업그레이드',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('괜찮아요'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kAccentPurple),
          onPressed: () {
            Navigator.of(context).pop();
            onUpgrade();
          },
          child: const Text('업그레이드'),
        ),
      ],
    ),
  );
}

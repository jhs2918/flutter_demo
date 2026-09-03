import 'package:flutter/material.dart';

import '../state/font_scale_controller.dart';
import '../theme/pastel_palette.dart';

/// [낱말카드 개편] 화면 상단 고정 영역에 두는 "글자크기" 토글 버튼 + 펼쳐지는
/// 슬라이더 패널. 드래그 즉시 [FontScaleController]에 반영되어 앱 전체
/// 글자 크기가 실시간으로 바뀐다(적용 버튼 없음).
class FontScaleBar extends StatefulWidget {
  const FontScaleBar({super.key});

  @override
  State<FontScaleBar> createState() => _FontScaleBarState();
}

class _FontScaleBarState extends State<FontScaleBar> {
  bool _expanded = false;

  static const List<(String, double)> _presets = <(String, double)>[
    ('작게 90%', 0.9),
    ('보통 100%', 1.0),
    ('크게 130%', 1.3),
    ('아주크게 160%', 1.6),
  ];

  @override
  Widget build(BuildContext context) {
    final FontScaleController controller = FontScaleScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        final int percent = (controller.scale * 100).round();
        return Container(
          color: kPanelBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.text_fields,
                        color: kAccentPurple,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      // [글자크기 확대 시 화면 밖으로 넘치는 문제 수정] 글자가
                      // 커지면 "글자크기 160%"가 한 줄에 다 안 들어갈 수
                      // 있다 - Spacer + 고정폭 Text 조합 대신 Expanded로
                      // 감싸 필요하면 2줄로 자연스럽게 줄바꿈되게 한다(잘리지
                      // 않음).
                      Expanded(
                        child: Text(
                          '글자크기 $percent%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: kCardTitleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: kAccentPurple,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Slider(
                              value: controller.scale,
                              min: FontScaleController.min,
                              max: FontScaleController.max,
                              divisions:
                                  ((FontScaleController.max -
                                              FontScaleController.min) /
                                          0.1)
                                      .round(),
                              activeColor: kAccentPurple,
                              onChanged: (double value) =>
                                  controller.scale = value,
                            ),
                          ),
                          // [글자크기 확대 시 잘리는 문제 수정] 고정폭
                          // SizedBox 대신 최소폭만 지정해, 글자가 커져도
                          // 잘리지 않고 필요한 만큼 넓어지게 한다.
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 52),
                            child: Text(
                              '$percent%',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kCardTitleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final (String label, double value) in _presets)
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    percent == (value * 100).round()
                                    ? kWordButtonSelectedBg
                                    : Colors.white,
                                foregroundColor:
                                    percent == (value * 100).round()
                                    ? kWordButtonSelectedText
                                    : kWordButtonText,
                                side: const BorderSide(color: kCardBorder),
                              ),
                              onPressed: () => controller.scale = value,
                              child: Text(label),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

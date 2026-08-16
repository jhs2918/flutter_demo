import 'package:flutter/material.dart';

import '../models/card_catalog.dart';
import '../theme/pastel_palette.dart';
import '../widgets/font_scale_bar.dart';
import 'card_select_screen.dart';

/// [낱말카드 개편][2단계] 장기요양 등급을 고른다. 방문요양은 1~5등급만,
/// 주간보호는 1~5등급 + 인지지원등급을 보여준다(인지지원등급은 방문요양에서
/// 이용 불가이므로 절대 노출하지 않는다).
class GradeSelectScreen extends StatelessWidget {
  const GradeSelectScreen({super.key, required this.service});

  final CardService service;

  List<(String value, String label)> get _grades {
    final List<(String, String)> base = <(String, String)>[
      ('1', '1등급'),
      ('2', '2등급'),
      ('3', '3등급'),
      ('4', '4등급'),
      ('5', '5등급'),
    ];
    if (service == CardService.day) {
      base.add(('인지', '인지지원등급'));
    }
    return base;
  }

  void _select(BuildContext context, String grade) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CardSelectScreen(service: service, grade: grade),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('등급 선택'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          const FontScaleBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    '수급자의 장기요양 등급을 선택하세요',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kCardTitleColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // [버그 회피] GridView는 내부적으로 Sliver를 쓰기 때문에
                  // children을 명시적으로 다 넘겨도 뷰포트 근처 항목만
                  // 지연 생성된다(작은 화면에서 "인지지원등급"이 아예 빌드
                  // 안 되는 문제로 실제 발생). SingleChildScrollView + Column은
                  // 전부 즉시 빌드하므로 이 문제가 없다.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < _grades.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: SizedBox(
                                      height: 96,
                                      child: _GradeButton(
                                        label: _grades[i].$2,
                                        onTap: () =>
                                            _select(context, _grades[i].$1),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: i + 1 < _grades.length
                                        ? SizedBox(
                                            height: 96,
                                            child: _GradeButton(
                                              label: _grades[i + 1].$2,
                                              onTap: () => _select(
                                                context,
                                                _grades[i + 1].$1,
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kCardBorder, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: kCardTitleColor,
            ),
          ),
        ),
      ),
    );
  }
}

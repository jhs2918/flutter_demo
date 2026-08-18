import 'package:flutter/material.dart';

import '../models/card_catalog.dart';
import '../theme/pastel_palette.dart';
import '../widgets/font_scale_bar.dart';
import 'card_select_screen.dart';

/// [낱말카드 개편 v2][2단계] 시설을 고른 다음, 어떤 기록유형(급여제공기록/
/// 상태변화일지/업무수행일지/사례관리/직원상담)을 작성할지 고른다. 등급
/// 선택 단계는 없다 - 서비스 선택 다음 바로 이 화면으로 온다.
class RecordTypeSelectScreen extends StatelessWidget {
  const RecordTypeSelectScreen({super.key, required this.service});

  final CardService service;

  void _select(BuildContext context, String recordTypeId, String label) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CardSelectScreen(
          service: service,
          recordTypeId: recordTypeId,
          recordTypeLabel: label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Text(service == CardService.visit ? '방문요양' : '주간보호'),
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
                    '어떤 기록을 작성하시나요?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kCardTitleColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // [버그 회피] ListView/GridView는 children을 명시적으로
                  // 넘겨도 내부적으로 Sliver를 써서 뷰포트 근처 항목만 지연
                  // 생성된다. 항목이 5개뿐이라도 같은 문제를 반복하지 않도록
                  // SingleChildScrollView + Column으로 전부 즉시 빌드한다.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          for (final (String id, String label)
                              in kRecordTypeOrder)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: SizedBox(
                                height: 72,
                                child: _RecordTypeButton(
                                  label: label,
                                  onTap: () => _select(context, id, label),
                                ),
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

class _RecordTypeButton extends StatelessWidget {
  const _RecordTypeButton({required this.label, required this.onTap});

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

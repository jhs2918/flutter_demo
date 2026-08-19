import 'package:flutter/material.dart';

import '../models/card_catalog.dart';
import '../services/card_catalog_repository.dart';
import '../theme/pastel_palette.dart';
import '../widgets/font_scale_bar.dart';
import 'card_select_screen.dart';

/// [낱말카드 개편 v2][2단계] 시설을 고른 다음, 어떤 기록유형을 작성할지
/// 고른다. 등급 선택 단계는 없다 - 서비스 선택 다음 바로 이 화면으로 온다.
/// 기록유형 목록은 하드코딩하지 않고 cards.json에서 그 시설에 실제로 있는
/// 것만 읽어온다 - 그래야 주간보호 전용 "프로그램평가"처럼 시설마다 개수가
/// 다른 기록유형도 따로 목록을 관리할 필요 없이 자동으로 맞게 나온다.
class RecordTypeSelectScreen extends StatefulWidget {
  const RecordTypeSelectScreen({super.key, required this.service});

  final CardService service;

  @override
  State<RecordTypeSelectScreen> createState() =>
      _RecordTypeSelectScreenState();
}

class _RecordTypeSelectScreenState extends State<RecordTypeSelectScreen> {
  final CardCatalogRepository _repository = CardCatalogRepository();
  List<CardRecordType>? _recordTypes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final CardCatalog catalog = await _repository.load();
    if (!mounted) return;
    setState(() {
      _recordTypes = catalog.recordTypesFor(widget.service);
    });
  }

  void _select(String recordTypeId, String label) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CardSelectScreen(
          service: widget.service,
          recordTypeId: recordTypeId,
          recordTypeLabel: label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<CardRecordType>? recordTypes = _recordTypes;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Text(widget.service == CardService.visit ? '방문요양' : '주간보호'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: recordTypes == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                        // 넘겨도 내부적으로 Sliver를 써서 뷰포트 근처 항목만
                        // 지연 생성된다. 항목이 몇 개뿐이라도 같은 문제를
                        // 반복하지 않도록 SingleChildScrollView + Column으로
                        // 전부 즉시 빌드한다.
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: <Widget>[
                                for (final CardRecordType recordType
                                    in recordTypes)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 16,
                                    ),
                                    child: SizedBox(
                                      height: 72,
                                      child: _RecordTypeButton(
                                        label: recordType.label,
                                        onTap: () => _select(
                                          recordType.id,
                                          recordType.label,
                                        ),
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

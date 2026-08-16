import 'package:flutter/material.dart';

import '../models/card_catalog.dart';
import '../services/ai_record_api.dart';
import '../services/card_catalog_repository.dart';
import '../state/font_scale_controller.dart';
import '../theme/pastel_palette.dart';
import '../widgets/ai_generating_dialog.dart';
import '../widgets/font_scale_bar.dart';
import 'ai_generation_result_screen.dart';

// 등급 강조 배경색. 선택 여부(테두리+체크)와는 완전히 다른 시각 채널이라야
// 하므로, "선택됨" 강조에 쓰는 보라 계열과 겹치지 않는 색을 쓴다.
const Color _kHighlightBg = Color(0xFFFFE49A);
const Color _kHighlightText = Color(0xFF7A5B00);
const Color _kNeutralBg = Color(0xFFF1F1F1);
const Color _kNeutralText = Color(0xFF444444);

/// [낱말카드 개편][3단계] 카테고리(접기/펼치기) → 그룹 → 항목 카드를 보여주고
/// 선택하는 화면. 등급에 해당하는 항목은 강조 + 그룹 안에서 맨 위로
/// 정렬되고, 서비스 종류에 맞지 않는 카테고리/항목은 숨긴다.
class CardSelectScreen extends StatefulWidget {
  const CardSelectScreen({
    super.key,
    required this.service,
    required this.grade,
  });

  final CardService service;
  // "1"~"5" 또는 "인지".
  final String grade;

  @override
  State<CardSelectScreen> createState() => _CardSelectScreenState();
}

class _CardSelectScreenState extends State<CardSelectScreen> {
  final CardCatalogRepository _repository = CardCatalogRepository();
  final AiRecordApi _aiRecordApi = const AiRecordApi();
  final TextEditingController _opinionController = TextEditingController();

  CardCatalog? _catalog;
  final Set<String> _selected = <String>{};
  final Map<String, String> _numericValues = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _opinionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final CardCatalog catalog = await _repository.load();
    if (!mounted) return;
    setState(() => _catalog = catalog);
  }

  String _key(CardCategory category, CardGroup group, CardItem item) =>
      '${category.id}::${group.name}::${item.label}';

  String get _gradeLabel =>
      widget.grade == '인지' ? '인지지원등급' : '${widget.grade}등급';

  List<CardCategory> get _visibleCategories {
    final CardCatalog? catalog = _catalog;
    if (catalog == null) return const <CardCategory>[];
    return catalog.categories
        .where((CardCategory c) => c.service.visibleFor(widget.service))
        .toList();
  }

  // 등급 강조 항목을 그룹 안에서 맨 위로, 나머지는 원래 순서 그대로 뒤에
  // 남긴다(List.sort는 안정 정렬이 보장되지 않아 where()로 직접 나눈다).
  List<CardItem> _sortedItems(List<CardItem> items) {
    final List<CardItem> highlighted = items
        .where((CardItem i) => i.isHighlightedFor(widget.grade))
        .toList();
    final List<CardItem> rest = items
        .where((CardItem i) => !i.isHighlightedFor(widget.grade))
        .toList();
    return <CardItem>[...highlighted, ...rest];
  }

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Map<String, List<String>> _buildPayload({String? additionalRequest}) {
    final List<String> statusLabels = <String>[];
    final List<String> actionLabels = <String>[];
    final List<String> numericLines = <String>[];

    for (final CardCategory category in _visibleCategories) {
      for (final CardGroup group in category.groups) {
        for (final CardItem item in group.items) {
          if (!item.service.visibleFor(widget.service)) continue;
          final String key = _key(category, group, item);
          if (item.isNumberInput) {
            final String? value = _numericValues[key];
            if (value != null && value.trim().isNotEmpty) {
              numericLines.add(
                '${item.label} ${value.trim()}${item.unit ?? ''}',
              );
            }
          } else if (_selected.contains(key)) {
            if (item.type == 'action') {
              actionLabels.add(item.label);
            } else {
              statusLabels.add(item.label);
            }
          }
        }
      }
    }

    final String opinion = _opinionController.text.trim();
    final Map<String, List<String>> payload = <String, List<String>>{
      '서비스종류': <String>[widget.service == CardService.visit ? '방문요양' : '주간보호'],
      '등급': <String>[_gradeLabel],
      if (statusLabels.isNotEmpty) '관찰된상태': statusLabels,
      if (actionLabels.isNotEmpty) '제공한조치': actionLabels,
      if (numericLines.isNotEmpty) '수치입력': numericLines,
      if (opinion.isNotEmpty) '수급자의견': <String>[opinion],
    };
    if (additionalRequest != null && additionalRequest.trim().isNotEmpty) {
      payload['추가요청'] = <String>[additionalRequest.trim()];
    }
    return payload;
  }

  bool get _hasAnyContent {
    if (_selected.isNotEmpty) return true;
    if (_opinionController.text.trim().isNotEmpty) return true;
    return _numericValues.values.any((String v) => v.trim().isNotEmpty);
  }

  Future<void> _generate() async {
    final Map<String, List<String>> payload = _buildPayload();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const AiGeneratingDialog(),
    );

    String text;
    try {
      text = await _aiRecordApi.generate(payload);
    } on AiRecordApiException catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AiGenerationResultScreen(
          initialStatusText: text,
          onRegenerate: (String additionalRequest) => _aiRecordApi.generate(
            _buildPayload(additionalRequest: additionalRequest),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double scale = FontScaleScope.of(context).scale;
    final CardCatalog? catalog = _catalog;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('카드 선택'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                const FontScaleBar(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        '$_gradeLabel · ${widget.service == CardService.visit ? "방문요양" : "주간보호"}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kSubHeaderColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '선택 항목 ${_selected.length}개',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kAccentPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                // [버그 회피] ListView(children:)도 내부적으로 Sliver를 쓰기
                // 때문에 뷰포트 근처 항목만 지연 생성된다. 카테고리가 26개로
                // 늘어날 다음 단계를 대비해, 전부 즉시 빌드하는
                // SingleChildScrollView + Column으로 만든다.
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Column(
                      children: <Widget>[
                        for (final CardCategory category in _visibleCategories)
                          _CategoryPanel(
                            category: category,
                            scale: scale,
                            sortedItemsOf: _sortedItems,
                            visibleItemsOf: (List<CardItem> items) => items
                                .where(
                                  (CardItem i) =>
                                      i.service.visibleFor(widget.service),
                                )
                                .toList(),
                            keyOf: (CardGroup group, CardItem item) =>
                                _key(category, group, item),
                            isSelected: _selected.contains,
                            isHighlighted: (CardItem item) =>
                                item.isHighlightedFor(widget.grade),
                            onToggle: _toggle,
                            numericValues: _numericValues,
                            onNumericChanged: (String key, String value) {
                              setState(() => _numericValues[key] = value);
                            },
                          ),
                        _OpinionSection(
                          controller: _opinionController,
                          scale: scale,
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _hasAnyContent ? _generate : null,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('문장 생성'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.category,
    required this.scale,
    required this.sortedItemsOf,
    required this.visibleItemsOf,
    required this.keyOf,
    required this.isSelected,
    required this.isHighlighted,
    required this.onToggle,
    required this.numericValues,
    required this.onNumericChanged,
  });

  final CardCategory category;
  final double scale;
  final List<CardItem> Function(List<CardItem> items) sortedItemsOf;
  final List<CardItem> Function(List<CardItem> items) visibleItemsOf;
  final String Function(CardGroup group, CardItem item) keyOf;
  final bool Function(String key) isSelected;
  final bool Function(CardItem item) isHighlighted;
  final ValueChanged<String> onToggle;
  final Map<String, String> numericValues;
  final void Function(String key, String value) onNumericChanged;

  @override
  Widget build(BuildContext context) {
    // ExpansionTile의 헤더는 ListTile이라 잉크 효과를 가장 가까운 Material
    // 조상에 그린다. 배경색을 바깥 DecoratedBox/Container에 두면 그 위에서
    // 잉크가 가려진다는 프레임워크 경고가 뜨므로, 배경은 Material에 주고
    // 테두리만 별도 Container로 그린다.
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              category.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: kCardTitleColor,
              ),
            ),
            children: <Widget>[
              for (final CardGroup group in category.groups)
                _GroupSection(
                  group: group,
                  scale: scale,
                  items: sortedItemsOf(visibleItemsOf(group.items)),
                  keyOf: (CardItem item) => keyOf(group, item),
                  isSelected: isSelected,
                  isHighlighted: isHighlighted,
                  onToggle: onToggle,
                  numericValues: numericValues,
                  onNumericChanged: onNumericChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.scale,
    required this.items,
    required this.keyOf,
    required this.isSelected,
    required this.isHighlighted,
    required this.onToggle,
    required this.numericValues,
    required this.onNumericChanged,
  });

  final CardGroup group;
  final double scale;
  final List<CardItem> items;
  final String Function(CardItem item) keyOf;
  final bool Function(String key) isSelected;
  final bool Function(CardItem item) isHighlighted;
  final ValueChanged<String> onToggle;
  final Map<String, String> numericValues;
  final void Function(String key, String value) onNumericChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 14 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            group.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: kSubHeaderColor,
            ),
          ),
          SizedBox(height: 8 * scale),
          Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: <Widget>[
              for (final CardItem item in items)
                if (item.isNumberInput)
                  _NumberInputChip(
                    scale: scale,
                    label: item.label,
                    unit: item.unit ?? '',
                    initialValue: numericValues[keyOf(item)] ?? '',
                    onChanged: (String value) =>
                        onNumericChanged(keyOf(item), value),
                  )
                else
                  _CardItemChip(
                    scale: scale,
                    label: item.label,
                    highlighted: isHighlighted(item),
                    selected: isSelected(keyOf(item)),
                    onTap: () => onToggle(keyOf(item)),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

// 세 가지 상태(기본/등급강조/선택됨)를 서로 다른 시각 채널로 동시에 표현한다.
// 배경색 = 등급 강조 여부, 테두리+체크 아이콘 = 선택 여부. 같은 채널(둘 다
// 배경색)을 쓰면 등급강조+선택이 겹쳤을 때 구분이 안 되므로 절대 섞지 않는다.
class _CardItemChip extends StatelessWidget {
  const _CardItemChip({
    required this.scale,
    required this.label,
    required this.highlighted,
    required this.selected,
    required this.onTap,
  });

  final double scale;
  final String label;
  final bool highlighted;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = highlighted ? _kHighlightBg : _kNeutralBg;
    final Color textColor = highlighted ? _kHighlightText : _kNeutralText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 10 * scale,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? kAccentPurple : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                const Icon(Icons.check_circle, size: 16, color: kAccentPurple),
                SizedBox(width: 6 * scale),
              ],
              Text(
                label,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberInputChip extends StatefulWidget {
  const _NumberInputChip({
    required this.scale,
    required this.label,
    required this.unit,
    required this.initialValue,
    required this.onChanged,
  });

  final double scale;
  final String label;
  final String unit;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_NumberInputChip> createState() => _NumberInputChipState();
}

class _NumberInputChipState extends State<_NumberInputChip> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * widget.scale,
        vertical: 8 * widget.scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            widget.label,
            style: const TextStyle(
              color: kCardTitleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8 * widget.scale),
          SizedBox(
            width: 64 * widget.scale,
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          SizedBox(width: 6 * widget.scale),
          Text(widget.unit, style: const TextStyle(color: kSubHeaderColor)),
        ],
      ),
    );
  }
}

class _OpinionSection extends StatelessWidget {
  const _OpinionSection({required this.controller, required this.scale});

  final TextEditingController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 12 * scale),
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '수급자·보호자 의견 (선택)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: kCardTitleColor,
            ),
          ),
          SizedBox(height: 8 * scale),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '예) 허리가 아파서 화장실 가기가 무섭다고 하심',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: kCardBorder),
              ),
            ),
          ),
          SizedBox(height: 6 * scale),
          const Text(
            '어르신이나 보호자가 직접 하신 말씀을 적어주세요',
            style: TextStyle(color: kSubHeaderColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

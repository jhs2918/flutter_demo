import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/saved_card_combination.dart';
import '../state/font_scale_controller.dart';
import '../theme/pastel_palette.dart';
import '../widgets/font_scale_bar.dart';

/// [17] 저장된 카드 조합 + AI 결과 목록 화면. 각 항목은 그때 선택했던 단어
/// 조합을 헤더로 보여준다. 헤더를 처음 탭하면 펼쳐져서 저장된 결과 문장이
/// (복사 버튼과 함께) 보이고, 펼쳐진 상태에서 헤더를 한 번 더 탭하면 그
/// 조합을 반환하며 화면이 닫힌다 - 호출부(카드 선택 화면)가 그 값을 받아
/// 현재 선택 상태에 그대로 반영한다.
class SavedCombinationsScreen extends StatefulWidget {
  const SavedCombinationsScreen({
    super.key,
    required this.combinations,
    required this.labelOf,
    required this.onDelete,
  });

  final List<SavedCardCombination> combinations;
  final String Function(String key) labelOf;
  final Future<void> Function(DateTime savedAt) onDelete;

  @override
  State<SavedCombinationsScreen> createState() =>
      _SavedCombinationsScreenState();
}

class _SavedCombinationsScreenState extends State<SavedCombinationsScreen> {
  late List<SavedCardCombination> _combinations = widget.combinations;

  Future<void> _delete(SavedCardCombination combo) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('저장 삭제'),
            content: const Text('이 저장 항목을 삭제할까요?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    await widget.onDelete(combo.savedAt);
    if (!mounted) return;
    setState(() {
      _combinations = _combinations
          .where((SavedCardCombination c) => c.savedAt != combo.savedAt)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double scale = FontScaleScope.of(context).scale;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('저장된 기록'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          const FontScaleBar(),
          Expanded(
            child: _combinations.isEmpty
                ? const Center(child: Text('저장된 기록이 없습니다.'))
                : ListView.separated(
                    padding: EdgeInsets.all(16 * scale),
                    itemCount: _combinations.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        SizedBox(height: 12 * scale),
                    itemBuilder: (BuildContext context, int index) {
                      final SavedCardCombination combo = _combinations[index];
                      return _SavedCombinationTile(
                        scale: scale,
                        combination: combo,
                        labelOf: widget.labelOf,
                        onChoose: () => Navigator.of(context).pop(combo),
                        onDelete: () => _delete(combo),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// 항목 하나: 접혀 있으면 단어조합 헤더만, 펼치면 그 아래 저장된 결과
// 문장들(복사 버튼 포함)까지 보여준다.
class _SavedCombinationTile extends StatefulWidget {
  const _SavedCombinationTile({
    required this.scale,
    required this.combination,
    required this.labelOf,
    required this.onChoose,
    required this.onDelete,
  });

  final double scale;
  final SavedCardCombination combination;
  final String Function(String key) labelOf;
  final VoidCallback onChoose;
  final VoidCallback onDelete;

  @override
  State<_SavedCombinationTile> createState() => _SavedCombinationTileState();
}

class _SavedCombinationTileState extends State<_SavedCombinationTile> {
  bool _expanded = false;

  // 헤더(단어조합)를 탭했을 때: 접혀 있으면 펼치고, 이미 펼쳐져 있으면 이
  // 조합을 그대로 메인 화면 선택 상태로 불러온다.
  void _handleHeaderTap() {
    if (_expanded) {
      widget.onChoose();
    } else {
      setState(() => _expanded = true);
    }
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('복사되었습니다.')));
  }

  String _formatSavedAt(DateTime dt) {
    final String mm = dt.month.toString().padLeft(2, '0');
    final String dd = dt.day.toString().padLeft(2, '0');
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String min = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final double scale = widget.scale;
    final SavedCardCombination combo = widget.combination;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: _handleHeaderTap,
            child: Padding(
              padding: EdgeInsets.all(14 * scale),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _formatSavedAt(combo.savedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: kSubHeaderColor,
                          ),
                        ),
                        SizedBox(height: 6 * scale),
                        Wrap(
                          spacing: 6 * scale,
                          runSpacing: 6 * scale,
                          children: <Widget>[
                            for (final String key in combo.selectedKeys)
                              Chip(
                                label: Text(widget.labelOf(key)),
                                backgroundColor: kWordButtonBg,
                                labelStyle: const TextStyle(
                                  color: kWordButtonText,
                                  fontWeight: FontWeight.w600,
                                ),
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        SizedBox(height: 6 * scale),
                        Text(
                          _expanded ? '탭하면 이 조합을 불러옵니다' : '탭하면 결과를 펼칩니다',
                          style: const TextStyle(
                            fontSize: 11,
                            color: kAccentPurple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: kSubHeaderColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              color: kPanelBg,
              padding: EdgeInsets.fromLTRB(
                14 * scale,
                0,
                14 * scale,
                14 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (combo.opinion.isNotEmpty) ...<Widget>[
                    SizedBox(height: 10 * scale),
                    Text(
                      '수급자·보호자 의견: ${combo.opinion}',
                      style: const TextStyle(color: kSubHeaderColor),
                    ),
                  ],
                  SizedBox(height: 10 * scale),
                  for (final SavedResultEntry result in combo.results)
                    if (result.text.trim().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8 * scale),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12 * scale),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kCardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      '[${result.label}]',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: kSubHeaderColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _copy(context, result.text),
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.copy,
                                        size: 16,
                                        color: kAccentPurple,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4 * scale),
                              Text(
                                result.text,
                                style: const TextStyle(
                                  color: kCardTitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

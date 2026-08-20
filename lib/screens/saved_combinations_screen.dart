import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/saved_card_combination.dart';
import '../state/font_scale_controller.dart';
import '../theme/pastel_palette.dart';
import '../widgets/font_scale_bar.dart';

/// [18] 저장된 이름 목록 화면. 저장은 이름을 지정해서 하며, 같은 이름으로
/// 여러 번 저장하면 그 이름 아래에 리스트로 쌓인다. 여기서는 이름과 그
/// 이름 아래 저장된 개수만 보여주고, 이름을 탭하면 [SavedNameEntriesScreen]
/// 으로 이동해 그 이름 안의 저장 항목들을 본다. 이름 자체도 통째로 삭제할
/// 수 있다.
class SavedCombinationsScreen extends StatefulWidget {
  const SavedCombinationsScreen({
    super.key,
    required this.combinations,
    required this.labelOf,
    required this.onDeleteEntry,
    required this.onDeleteName,
  });

  final List<SavedCardCombination> combinations;
  final String Function(String key) labelOf;
  final Future<void> Function(DateTime savedAt) onDeleteEntry;
  final Future<void> Function(String name) onDeleteName;

  @override
  State<SavedCombinationsScreen> createState() =>
      _SavedCombinationsScreenState();
}

class _SavedCombinationsScreenState extends State<SavedCombinationsScreen> {
  late List<SavedCardCombination> _combinations = widget.combinations;

  // 이름별로 묶되, 이름 그룹의 순서는 그 안에서 가장 최근 저장 시각 기준.
  List<MapEntry<String, List<SavedCardCombination>>> get _grouped {
    final Map<String, List<SavedCardCombination>> byName =
        <String, List<SavedCardCombination>>{};
    for (final SavedCardCombination combo in _combinations) {
      byName.putIfAbsent(combo.name, () => <SavedCardCombination>[]).add(combo);
    }
    final List<MapEntry<String, List<SavedCardCombination>>> entries = byName
        .entries
        .toList();
    entries.sort((
      MapEntry<String, List<SavedCardCombination>> a,
      MapEntry<String, List<SavedCardCombination>> b,
    ) {
      final DateTime aLatest = a.value.first.savedAt;
      final DateTime bLatest = b.value.first.savedAt;
      return bLatest.compareTo(aLatest);
    });
    return entries;
  }

  Future<void> _deleteName(String name) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('이름 삭제'),
            content: Text('"$name" 이름 아래 저장된 항목을 모두 삭제할까요?'),
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

    await widget.onDeleteName(name);
    if (!mounted) return;
    setState(() {
      _combinations = _combinations
          .where((SavedCardCombination c) => c.name != name)
          .toList();
    });
  }

  Future<void> _openNameEntries(
    String name,
    List<SavedCardCombination> entries,
  ) async {
    final SavedCardCombination? chosen = await Navigator.of(context)
        .push<SavedCardCombination>(
          MaterialPageRoute<SavedCardCombination>(
            builder: (BuildContext context) => SavedNameEntriesScreen(
              name: name,
              entries: entries,
              labelOf: widget.labelOf,
              onDeleteEntry: (DateTime savedAt) async {
                await widget.onDeleteEntry(savedAt);
                setState(() {
                  _combinations = _combinations
                      .where((SavedCardCombination c) => c.savedAt != savedAt)
                      .toList();
                });
              },
            ),
          ),
        );
    if (chosen != null && mounted) Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final double scale = FontScaleScope.of(context).scale;
    final List<MapEntry<String, List<SavedCardCombination>>> grouped =
        _grouped;

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
            child: grouped.isEmpty
                ? const Center(child: Text('저장된 기록이 없습니다.'))
                : ListView.separated(
                    padding: EdgeInsets.all(16 * scale),
                    itemCount: grouped.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        SizedBox(height: 12 * scale),
                    itemBuilder: (BuildContext context, int index) {
                      final String name = grouped[index].key;
                      final List<SavedCardCombination> entries =
                          grouped[index].value;
                      return _NameGroupTile(
                        scale: scale,
                        name: name,
                        entries: entries,
                        onTap: () => _openNameEntries(name, entries),
                        onDelete: () => _deleteName(name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NameGroupTile extends StatelessWidget {
  const _NameGroupTile({
    required this.scale,
    required this.name,
    required this.entries,
    required this.onTap,
    required this.onDelete,
  });

  final double scale;
  final String name;
  final List<SavedCardCombination> entries;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(14 * scale),
          child: Row(
            children: <Widget>[
              const Icon(Icons.folder, color: kAccentPurple),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kCardTitleColor,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      '저장 ${entries.length}건',
                      style: const TextStyle(
                        fontSize: 12,
                        color: kSubHeaderColor,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onDelete, child: const Text('삭제')),
            ],
          ),
        ),
      ),
    );
  }
}

/// [18] 이름 하나 아래 쌓인 저장 항목 목록 화면. 항목(단어조합) 헤더를
/// 처음 탭하면 펼쳐져서 저장된 결과 문장이 (복사 버튼과 함께) 보이고,
/// 펼쳐진 상태에서 헤더를 한 번 더 탭하면 그 조합을 반환하며 화면이
/// (이 화면과 이름 목록 화면 모두) 닫힌다.
class SavedNameEntriesScreen extends StatefulWidget {
  const SavedNameEntriesScreen({
    super.key,
    required this.name,
    required this.entries,
    required this.labelOf,
    required this.onDeleteEntry,
  });

  final String name;
  final List<SavedCardCombination> entries;
  final String Function(String key) labelOf;
  final Future<void> Function(DateTime savedAt) onDeleteEntry;

  @override
  State<SavedNameEntriesScreen> createState() =>
      _SavedNameEntriesScreenState();
}

class _SavedNameEntriesScreenState extends State<SavedNameEntriesScreen> {
  late List<SavedCardCombination> _entries = widget.entries;

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

    await widget.onDeleteEntry(combo.savedAt);
    if (!mounted) return;
    setState(() {
      _entries = _entries
          .where((SavedCardCombination c) => c.savedAt != combo.savedAt)
          .toList();
    });
    if (_entries.isEmpty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final double scale = FontScaleScope.of(context).scale;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Text(widget.name),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          const FontScaleBar(),
          Expanded(
            child: _entries.isEmpty
                ? const Center(child: Text('저장된 기록이 없습니다.'))
                : ListView.separated(
                    padding: EdgeInsets.all(16 * scale),
                    itemCount: _entries.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        SizedBox(height: 12 * scale),
                    itemBuilder: (BuildContext context, int index) {
                      final SavedCardCombination combo = _entries[index];
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
                  TextButton(
                    onPressed: widget.onDelete,
                    child: const Text('삭제'),
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
                                  // [18] 아이콘이 아닌 글자 버튼("복사").
                                  TextButton(
                                    onPressed: () =>
                                        _copy(context, result.text),
                                    style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('복사'),
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

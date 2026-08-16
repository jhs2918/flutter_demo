import 'package:flutter/material.dart';

import '../models/saved_name_group.dart';
import '../theme/pastel_palette.dart';
import '../utils/date_format.dart';

/// [저장개편] "내 저장" 이름 목록 전체를 최근 저장순으로 보여주는 화면.
/// 이름을 탭하면 그 이름을 반환하며 화면을 닫는다(호출한 쪽에서 기록 목록
/// 팝업을 이어서 띄운다). 이름을 길게 누르면 그 이름의 저장 항목 전체를
/// 삭제할 수 있다.
class MySavedScreen extends StatefulWidget {
  const MySavedScreen({
    super.key,
    required this.groups,
    required this.onDeleteGroup,
  });

  // 최근 저장순으로 정렬되어 전달된다.
  final List<SavedNameGroup> groups;
  final Future<void> Function(String name) onDeleteGroup;

  @override
  State<MySavedScreen> createState() => _MySavedScreenState();
}

class _MySavedScreenState extends State<MySavedScreen> {
  late List<SavedNameGroup> _groups = widget.groups;

  Future<void> _confirmDelete(SavedNameGroup group) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('저장 목록 삭제'),
            content: Text('"${group.name}"의 저장된 기록을 모두 삭제할까요?'),
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

    await widget.onDeleteGroup(group.name);
    if (!mounted) return;
    setState(() {
      _groups =
          _groups.where((SavedNameGroup g) => g.name != group.name).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('내 저장'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: _groups.isEmpty
          ? const Center(
              child: Text(
                '저장된 이름이 없습니다.',
                style: TextStyle(color: kCardTitleColor),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final SavedNameGroup group = _groups[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(group.name),
                    onLongPress: () => _confirmDelete(group),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kCardBorder),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: kCardTitleColor,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${group.entries.length}건 · 최근 ${formatDateTime(group.lastSavedAt)}',
                                  style: const TextStyle(
                                    color: kSubHeaderColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: kAccentPurple),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

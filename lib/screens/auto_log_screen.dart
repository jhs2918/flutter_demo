import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/word_combination_entry.dart';
import '../theme/pastel_palette.dart';
import '../utils/date_format.dart';

/// [저장개편] AI 문장을 생성할 때마다 자동으로 쌓이는 로그를 최신순으로
/// 보여주는 화면. 7일이 지난 기록은 record_screen에서 미리 걸러 전달한다.
/// 단어 조합을 탭하면 메인 화면에 그 조합이 자동 선택되고, 문장을 탭하면
/// 클립보드에 복사된다.
class AutoLogScreen extends StatelessWidget {
  const AutoLogScreen({
    super.key,
    required this.entries,
    required this.onSelectCombination,
  });

  // 최신순으로 정렬되어 전달된다.
  final List<WordCombinationEntry> entries;
  final ValueChanged<WordCombinationEntry> onSelectCombination;

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('복사되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('기록 보기'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                '최근 7일 이내 생성된 기록이 없습니다.',
                style: TextStyle(color: kCardTitleColor),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final WordCombinationEntry entry = entries[index];
                return _LogEntryCard(
                  entry: entry,
                  onSelectCombination: () => onSelectCombination(entry),
                  onCopy: () => _copy(context, entry.generatedText),
                );
              },
            ),
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({
    required this.entry,
    required this.onSelectCombination,
    required this.onCopy,
  });

  final WordCombinationEntry entry;
  final VoidCallback onSelectCombination;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            formatDateTime(entry.timestamp),
            style: const TextStyle(
              color: kSubHeaderColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (entry.words.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSelectCombination,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final String word in entry.words)
                    Chip(
                      label: Text(word),
                      backgroundColor: kWordButtonBg,
                      labelStyle: const TextStyle(color: kWordButtonText),
                      side: BorderSide.none,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onCopy,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPanelBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kCardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      entry.generatedText,
                      style: const TextStyle(color: kCardTitleColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy, size: 18, color: kAccentPurple),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

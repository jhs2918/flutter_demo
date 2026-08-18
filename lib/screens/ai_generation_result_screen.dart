import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/saved_card_combination.dart';
import '../services/ai_record_api.dart';
import '../state/font_scale_controller.dart';
import '../theme/pastel_palette.dart';
import '../widgets/font_scale_bar.dart';

// 자주 쓰는 재요청을 버튼 한 번으로 바로 보낼 수 있게 미리 준비해둔 문구.
const List<String> _kQuickRequests = <String>[
  '더 짧게 써줘',
  '더 자세히 써줘',
  '보호자 연락 내용도 넣어줘',
  '좀 더 부드러운 표현으로',
];

class _ResultEntry {
  _ResultEntry({
    required this.label,
    required String text,
    this.deletable = false,
  }) : controller = TextEditingController(text: text);

  final String label;
  final TextEditingController controller;
  final bool deletable;
}

/// [낱말카드 개편][7~8단계] AI가 생성한 문장을 보여주고, 직접 수정하거나
/// 추가 요청을 적어 다시 생성할 수 있는 화면. 재요청해도 기존에 만들어진
/// 결과는 그대로 두고, 그 아래에 새 결과 창을 하나 더 만들어 쌓아 보여준다
/// (계속 요청하면 계속 아래로 쌓인다). 재요청은 원래 선택했던 카드·수치·
/// 수급자의견은 그대로 유지된 채 추가 요청 문구만 얹어 다시 보낸다(재요청
/// 로직은 [onRegenerate] 콜백이 담당). [onSave]를 지정하면 지금까지의 모든
/// 결과 창 내용을 선택했던 카드와 함께 이름 붙여 저장할 수 있다.
class AiGenerationResultScreen extends StatefulWidget {
  const AiGenerationResultScreen({
    super.key,
    required this.initialStatusText,
    required this.initialActionText,
    required this.onRegenerate,
    this.selectedLabels = const <String>[],
    this.onSave,
  });

  final String initialStatusText;
  final String initialActionText;
  final Future<String> Function(String additionalRequest) onRegenerate;
  // [12] 결과 위에 "어떤 단어를 선택했는지" 보여줄 카드 라벨 목록.
  final List<String> selectedLabels;
  // 지정하면 "저장" 버튼이 나타난다. 이름과 지금까지의 결과 창 목록을 넘기면
  // 호출부(card_select_screen)가 현재 선택된 카드와 함께 저장한다.
  final Future<void> Function(String name, List<SavedResultEntry> results)?
  onSave;

  @override
  State<AiGenerationResultScreen> createState() =>
      _AiGenerationResultScreenState();
}

class _AiGenerationResultScreenState extends State<AiGenerationResultScreen> {
  final TextEditingController _refineController = TextEditingController();
  late final List<_ResultEntry> _entries = <_ResultEntry>[
    _ResultEntry(label: '상태', text: widget.initialStatusText),
    _ResultEntry(label: '조치', text: widget.initialActionText),
  ];
  bool _isRegenerating = false;

  @override
  void dispose() {
    _refineController.dispose();
    for (final _ResultEntry entry in _entries) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _regenerateWith(String request) async {
    if (request.trim().isEmpty || _isRegenerating) return;
    setState(() => _isRegenerating = true);

    try {
      final String text = await widget.onRegenerate(request.trim());
      if (!mounted) return;
      setState(() {
        _entries.add(
          _ResultEntry(label: request.trim(), text: text, deletable: true),
        );
        _refineController.clear();
      });
    } on AiRecordApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  Future<void> _send() => _regenerateWith(_refineController.text);

  void _deleteEntry(_ResultEntry entry) {
    setState(() {
      _entries.remove(entry);
      entry.controller.dispose();
    });
  }

  Future<void> _copy() async {
    final String combined = _entries
        .map((_ResultEntry e) => '[${e.label}]\n${e.controller.text}')
        .join('\n\n');
    await Clipboard.setData(ClipboardData(text: combined));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('복사되었습니다.')));
  }

  Future<void> _save() async {
    final Future<void> Function(String name, List<SavedResultEntry> results)?
    onSave = widget.onSave;
    if (onSave == null) return;

    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _SaveNameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;

    final List<SavedResultEntry> results = _entries
        .map(
          (_ResultEntry e) =>
              SavedResultEntry(label: e.label, text: e.controller.text),
        )
        .toList();
    await onSave(name.trim(), results);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    final double scale = FontScaleScope.of(context).scale;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('AI 기록 결과'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          const FontScaleBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16 * scale),
              child: Column(
                children: <Widget>[
                  if (widget.selectedLabels.isNotEmpty) ...<Widget>[
                    _SelectedWordsSummary(
                      scale: scale,
                      labels: widget.selectedLabels,
                    ),
                    SizedBox(height: 16 * scale),
                  ],
                  for (final _ResultEntry entry in _entries) ...<Widget>[
                    _ResultBox(
                      scale: scale,
                      entry: entry,
                      onDelete: entry.deletable
                          ? () => _deleteEntry(entry)
                          : null,
                    ),
                    SizedBox(height: 16 * scale),
                  ],
                  Container(
                    padding: EdgeInsets.all(16 * scale),
                    decoration: BoxDecoration(
                      color: kPanelBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kCardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '다시 요청하기',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: kCardTitleColor,
                          ),
                        ),
                        SizedBox(height: 4 * scale),
                        const Text(
                          '기존 결과는 그대로 남고, 아래에 새 결과가 추가됩니다',
                          style: TextStyle(
                            color: kSubHeaderColor,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        // 자주 쓰는 요청은 버튼 하나로 바로 보낼 수 있다.
                        Wrap(
                          spacing: 8 * scale,
                          runSpacing: 8 * scale,
                          children: <Widget>[
                            for (final String quick in _kQuickRequests)
                              ActionChip(
                                label: Text(quick),
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: kCardBorder),
                                labelStyle: const TextStyle(
                                  color: kWordButtonText,
                                ),
                                onPressed: _isRegenerating
                                    ? null
                                    : () => _regenerateWith(quick),
                              ),
                          ],
                        ),
                        SizedBox(height: 10 * scale),
                        // 채팅창처럼 입력창 + 보내기 버튼.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _refineController,
                                maxLines: 3,
                                minLines: 1,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: InputDecoration(
                                  hintText: '예) 더 짧게 써줘 / 보호자 연락한 내용도 넣어줘',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14 * scale,
                                    vertical: 10 * scale,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(
                                      color: kCardBorder,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8 * scale),
                            IconButton.filled(
                              onPressed: _isRegenerating ? null : _send,
                              icon: _isRegenerating
                                  ? SizedBox(
                                      width: 18 * scale,
                                      height: 18 * scale,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16 * scale,
                8 * scale,
                16 * scale,
                12 * scale,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy),
                      label: const Text('복사'),
                    ),
                  ),
                  if (widget.onSave != null) ...<Widget>[
                    SizedBox(width: 8 * scale),
                    OutlinedButton.icon(
                      onPressed: _save,
                      icon: const Text('💾'),
                      label: const Text('저장'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// [12] 결과 위에 "어떤 단어를 선택했는지" 보여주는 읽기 전용 요약. 선택
// 화면의 칩과 달리 여기서는 삭제/토글이 필요 없어 단순 Chip으로만 나열한다.
class _SelectedWordsSummary extends StatelessWidget {
  const _SelectedWordsSummary({required this.scale, required this.labels});

  final double scale;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: kPanelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '선택한 항목 (${labels.length}개)',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kCardTitleColor,
            ),
          ),
          SizedBox(height: 8 * scale),
          Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: <Widget>[
              for (final String label in labels)
                Chip(
                  label: Text(label),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: kCardBorder),
                  labelStyle: const TextStyle(color: kWordButtonText),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  const _ResultBox({
    required this.scale,
    required this.entry,
    required this.onDelete,
  });

  final double scale;
  final _ResultEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '[${entry.label}]',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kAccentPurple,
                  ),
                ),
              ),
              if (onDelete != null)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18, color: kSubHeaderColor),
                  ),
                ),
            ],
          ),
          SizedBox(height: 10 * scale),
          TextField(
            controller: entry.controller,
            maxLines: null,
            minLines: 3,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: kCardBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 저장 이름 입력 다이얼로그.
class _SaveNameDialog extends StatefulWidget {
  const _SaveNameDialog();

  @override
  State<_SaveNameDialog> createState() => _SaveNameDialogState();
}

class _SaveNameDialogState extends State<_SaveNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('저장'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '저장할 이름 (예: 김할머니)'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

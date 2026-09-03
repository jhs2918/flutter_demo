import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/saved_card_combination.dart';
import '../services/ai_record_api.dart';
import '../state/font_scale_controller.dart';
import '../theme/pastel_palette.dart';
import '../widgets/font_scale_bar.dart';

// 자주 쓰는 재요청을 버튼 한 번으로 바로 보낼 수 있게 미리 준비해둔 문구.
// [조치 재선택] "다른 조치로 다시 써줘"는 여기 없다 - 텍스트 요청만으로는
// 조치(action) 항목이 그대로 프롬프트에 남아있어 AI가 실제로 하지 않은
// 조치를 지어낼 위험이 있다(기록의 사실성 문제). 대신 아래 "다른 조치
// 선택하기" 버튼으로 실제 재선택을 유도한다.
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

/// [낱말카드 개편][7~8단계][17] AI가 생성한 문장을 보여주고, 직접 수정하거나
/// 추가 요청을 적어 다시 생성할 수 있는 화면. 재요청해도 기존에 만들어진
/// 결과는 그대로 두고, 그 아래에 새 결과 창을 하나 더 만들어 쌓아 보여준다
/// (계속 요청하면 계속 아래로 쌓인다). 재요청은 원래 선택했던 카드·수치·
/// 수급자의견은 그대로 유지된 채 추가 요청 문구만 얹어 다시 보낸다(재요청
/// 로직은 [onRegenerate] 콜백이 담당). [onSave]를 지정하면 "저장" 버튼이
/// 나타나고, 누르면 이름을 묻지 않고 바로 저장 목록에 새 항목으로 쌓인다
/// (겹쳐쓰지 않음).
class AiGenerationResultScreen extends StatefulWidget {
  const AiGenerationResultScreen({
    super.key,
    required this.initialTexts,
    required this.onRegenerate,
    required this.onPickDifferentAction,
    this.selectedLabels = const <String>[],
    this.onSave,
    this.existingNames = const <String>[],
  });

  // [23] 합치기를 골랐으면 문자열 1개, 항목별로 나누기를 골랐으면 여러
  // 개 - 각각 독립된 결과 박스로 보여준다.
  final List<String> initialTexts;
  final Future<String> Function(String additionalRequest) onRegenerate;
  // [조치 재선택] "다른 조치 선택하기"를 누르면 호출부(card_select_screen)가
  // 기존에 골랐던 조치(action) 카드 선택을 지우고 그 카테고리로 스크롤해
  // 준다 - 이 화면은 그다음 자신을 pop해서 카드 선택 화면으로 돌아간다.
  final VoidCallback onPickDifferentAction;
  // [12] 결과 위에 "어떤 단어를 선택했는지" 보여줄 카드 라벨 목록.
  final List<String> selectedLabels;
  // 지정하면 "저장" 버튼이 나타난다. 이름과 지금까지의 결과 창 목록을
  // 넘기면 호출부(card_select_screen)가 현재 선택된 카드와 함께, 그 이름
  // 아래 리스트로 저장한다(겹쳐쓰지 않음).
  final Future<void> Function(String name, List<SavedResultEntry> results)?
  onSave;
  // [18] 저장 이름 입력 시 빠르게 고를 수 있게 보여줄 기존 이름 목록.
  final List<String> existingNames;

  @override
  State<AiGenerationResultScreen> createState() =>
      _AiGenerationResultScreenState();
}

class _AiGenerationResultScreenState extends State<AiGenerationResultScreen> {
  final TextEditingController _refineController = TextEditingController();
  // [19][23] 초기 결과는 라벨 없이 박스로 둔다 - 합치기를 골랐으면 박스
  // 1개, 항목별로 나누기를 골랐으면 항목 수만큼 박스가 생긴다. 재요청
  // 결과는 요청 문구를 라벨 삼아 그 아래에 계속 쌓인다(기존 동작 유지).
  late final List<_ResultEntry> _entries = <_ResultEntry>[
    for (final String text in widget.initialTexts)
      _ResultEntry(label: '', text: text),
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

  // [다소 제거] "다소" 같은 모호한 표현을 AI가 자주 넣는 경우를 대비해, AI에게
  // 다시 써달라고 요청함과 동시에 돌아온 결과에서도 "다소"가 남아있지 않도록
  // 한 번 더 직접 지운다(요청만으로는 AI가 완전히 지키지 않을 수 있어서).
  String _stripDaso(String text) {
    return text
        .replaceAll('다소', '')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\s+([.,·])'), r'$1')
        .trim();
  }

  Future<void> _rewriteWithoutDaso() async {
    if (_isRegenerating) return;
    setState(() => _isRegenerating = true);

    try {
      final String text = await widget.onRegenerate('"다소"라는 표현 없이 다시 써줘');
      if (!mounted) return;
      setState(() {
        _entries.add(
          _ResultEntry(
            label: '다소 없이 다시 작성',
            text: _stripDaso(text),
            deletable: true,
          ),
        );
      });
    } on AiRecordApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  // [조치 재선택] 카드 선택 화면으로 돌아가면 이 화면은 닫혀서 지금까지
  // 쌓인 결과창(저장 안 한 것)이 사라지므로, 진행 전에 한 번 확인한다.
  Future<void> _pickDifferentAction() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('다른 조치 선택하기'),
            content: const Text(
              '조치 카드를 다시 고르러 이전 화면으로 돌아갑니다.\n'
              '지금까지 생성된 결과 중 저장하지 않은 내용은 사라집니다.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    widget.onPickDifferentAction();
    Navigator.of(context).pop();
  }

  void _deleteEntry(_ResultEntry entry) {
    setState(() {
      _entries.remove(entry);
      entry.controller.dispose();
    });
  }

  Future<void> _copy() async {
    final String combined = _entries
        .map(
          (_ResultEntry e) => e.label.isEmpty
              ? e.controller.text
              : '[${e.label}]\n${e.controller.text}',
        )
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
      builder: (BuildContext context) =>
          _SaveNameDialog(existingNames: widget.existingNames),
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

  Future<void> _copyEntry(_ResultEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.controller.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('복사되었습니다.')));
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
                      onCopy: () => _copyEntry(entry),
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
                            fontSize: 14,
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
                        // [조치 재선택] 조치는 실제 수행 여부가 중요한
                        // 기록이라, 텍스트로 "다른 조치로 다시 써줘"라고
                        // 요청하는 대신 카드 선택 화면으로 돌아가 실제로
                        // 다른 조치를 고르게 한다.
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isRegenerating
                                ? null
                                : _pickDifferentAction,
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('다른 조치 선택하기'),
                          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  // [글자수 표시] 결과 상자들에 지금 담긴 전체 글자수. 직접
                  // 수정한 내용도 즉시 반영되도록 각 결과의 컨트롤러 변경을
                  // 그대로 듣는다.
                  AnimatedBuilder(
                    animation: Listenable.merge(
                      _entries.map((_ResultEntry e) => e.controller).toList(),
                    ),
                    builder: (BuildContext context, Widget? _) {
                      final int total = _entries.fold<int>(
                        0,
                        (int sum, _ResultEntry e) =>
                            sum + e.controller.text.length,
                      );
                      return Text(
                        '총 $total자',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kSubHeaderColor,
                          fontSize: 14 * scale,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 8 * scale),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isRegenerating ? null : _rewriteWithoutDaso,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('다소 없이 다시 작성'),
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Row(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// [18] 저장 이름을 입력받는 다이얼로그. 기존에 저장된 이름이 있으면 칩으로
// 보여줘서 탭 한 번으로 같은 이름을 다시 고를 수 있게 한다(그 이름 아래
// 리스트에 새 항목이 쌓임).
class _SaveNameDialog extends StatefulWidget {
  const _SaveNameDialog({required this.existingNames});

  final List<String> existingNames;

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

  void _submit() {
    final String name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('저장할 이름'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('예) 김할머니 - 같은 이름으로 저장하면 그 이름 아래 목록에 쌓입니다.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: '이름 입력',
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.existingNames.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              '기존 이름에서 선택',
              style: TextStyle(fontSize: 14, color: kSubHeaderColor),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String name in widget.existingNames)
                  ActionChip(
                    label: Text(name),
                    onPressed: () => _controller.text = name,
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
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
            spacing: 10 * scale,
            runSpacing: 10 * scale,
            children: <Widget>[
              for (final String label in labels)
                // [UI개선] 카드 선택 화면과 동일하게 진한 배경 + 두꺼운
                // 강조색 테두리 + 흰 글자로 뚜렷하게 표시한다.
                Chip(
                  label: Text(label),
                  backgroundColor: kWordButtonSelectedBg,
                  side: const BorderSide(
                    color: kCardSelectedBorder,
                    width: 2,
                  ),
                  labelStyle: const TextStyle(
                    color: kWordButtonSelectedText,
                    fontWeight: FontWeight.w700,
                  ),
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
    required this.onCopy,
    required this.onDelete,
  });

  final double scale;
  final _ResultEntry entry;
  final VoidCallback onCopy;
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
                child: entry.label.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        '[${entry.label}]',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: kAccentPurple,
                        ),
                      ),
              ),
              // [17][18] 결과창마다 개별 복사 버튼(아이콘이 아닌 글자 버튼).
              TextButton(
                onPressed: onCopy,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('복사'),
              ),
              if (onDelete != null) ...<Widget>[
                SizedBox(width: 4 * scale),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18, color: kSubHeaderColor),
                  ),
                ),
              ],
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

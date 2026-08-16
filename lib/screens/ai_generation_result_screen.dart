import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_record_api.dart';
import '../state/font_scale_controller.dart';
import '../theme/pastel_palette.dart';
import '../widgets/font_scale_bar.dart';

/// [낱말카드 개편][7~8단계] AI가 생성한 문장을 [상태]/[조치] 두 칸으로
/// 나누어 보여주고, 직접 수정하거나 추가 요청을 적어 다시 생성할 수 있는
/// 화면. 재요청해도 원래 선택했던 카드·수치·수급자의견은 그대로 유지된 채
/// 추가 요청 문구만 얹어 다시 보낸다(재요청 로직은 [onRegenerate] 콜백이
/// 담당).
///
/// 주의: 현재 백엔드(/generate)는 [상태]/[조치]를 구분하지 않고 하나로
/// 이어진 문장 하나만 돌려준다(프롬프트 수정은 이번 범위 밖). 그래서 생성된
/// 전체 문장은 우선 [상태] 칸에 넣어두고 [조치] 칸은 비워 직접 옮겨 적을 수
/// 있게 했다 - 백엔드가 두 칸을 구분해 반환하도록 바뀌면 이 초기 배치만
/// 바꾸면 된다.
class AiGenerationResultScreen extends StatefulWidget {
  const AiGenerationResultScreen({
    super.key,
    required this.initialStatusText,
    required this.onRegenerate,
  });

  final String initialStatusText;
  final Future<String> Function(String additionalRequest) onRegenerate;

  @override
  State<AiGenerationResultScreen> createState() =>
      _AiGenerationResultScreenState();
}

class _AiGenerationResultScreenState extends State<AiGenerationResultScreen> {
  late final TextEditingController _statusController = TextEditingController(
    text: widget.initialStatusText,
  );
  final TextEditingController _actionController = TextEditingController();
  final TextEditingController _refineController = TextEditingController();

  final List<({String status, String action})> _history =
      <({String status, String action})>[];
  bool _isRegenerating = false;

  @override
  void dispose() {
    _statusController.dispose();
    _actionController.dispose();
    _refineController.dispose();
    super.dispose();
  }

  Future<void> _regenerate() async {
    final String additional = _refineController.text.trim();
    if (additional.isEmpty || _isRegenerating) return;

    final ({String status, String action}) snapshot = (
      status: _statusController.text,
      action: _actionController.text,
    );
    setState(() => _isRegenerating = true);

    try {
      final String text = await widget.onRegenerate(additional);
      if (!mounted) return;
      setState(() {
        _history.add(snapshot);
        _statusController.text = text;
        _actionController.clear();
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

  void _undo() {
    if (_history.isEmpty) return;
    final ({String status, String action}) previous = _history.removeLast();
    setState(() {
      _statusController.text = previous.status;
      _actionController.text = previous.action;
    });
  }

  Future<void> _copy() async {
    final String combined =
        '[상태]\n${_statusController.text}\n\n[조치]\n${_actionController.text}';
    await Clipboard.setData(ClipboardData(text: combined));
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
                  _ResultBox(
                    scale: scale,
                    title: '상태',
                    subtitle: '관찰된 상태와 우려되는 점',
                    controller: _statusController,
                  ),
                  SizedBox(height: 16 * scale),
                  _ResultBox(
                    scale: scale,
                    title: '조치',
                    subtitle: '제공한 조치와 결과·계획',
                    controller: _actionController,
                  ),
                  SizedBox(height: 24 * scale),
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
                        SizedBox(height: 8 * scale),
                        TextField(
                          controller: _refineController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: '예) 더 짧게 써줘 / 보호자 연락한 내용도 넣어줘 / 좀 더 자세히',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: kCardBorder),
                            ),
                          ),
                        ),
                        SizedBox(height: 10 * scale),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isRegenerating ? null : _regenerate,
                                icon: _isRegenerating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                                label: const Text('다시 만들기'),
                              ),
                            ),
                            SizedBox(width: 8 * scale),
                            OutlinedButton.icon(
                              onPressed: _history.isEmpty ? null : _undo,
                              icon: const Icon(Icons.undo),
                              label: const Text('되돌리기'),
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
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy),
                  label: const Text('복사'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  const _ResultBox({
    required this.scale,
    required this.title,
    required this.subtitle,
    required this.controller,
  });

  final double scale;
  final String title;
  final String subtitle;
  final TextEditingController controller;

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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '[$title]',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kAccentPurple,
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(color: kSubHeaderColor, fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          TextField(
            controller: controller,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// [02-03] AI가 생성한 문장을 보여주고 직접 수정한 뒤 복사할 수 있는 화면.
class AiResultScreen extends StatefulWidget {
  const AiResultScreen({super.key, required this.initialText, this.onSave});

  final String initialText;
  // [전면개편-5][저장개편] 지정하면 "저장" 버튼이 나타나고, 눌렀을 때 현재
  // 텍스트(수정했다면 수정된 내용)를 저장한다. 선택 단어 조합은 호출부
  // (record_screen)가 이미 알고 있으므로 클로저로 캡처해 전달한다. 사용자가
  // 저장 이름 선택 팝업을 취소하는 등 실제로 저장되지 않았으면 false를
  // 반환해야 "저장되었습니다." 토스트가 잘못 뜨는 일이 없다.
  final Future<bool> Function(String text)? onSave;

  @override
  State<AiResultScreen> createState() => _AiResultScreenState();
}

class _AiResultScreenState extends State<AiResultScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('복사되었습니다.')),
    );
  }

  Future<void> _save() async {
    final Future<bool> Function(String text)? onSave = widget.onSave;
    if (onSave == null) return;
    final bool saved = await onSave(_controller.text);
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 기록 결과')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy),
                  label: const Text('복사'),
                ),
              ),
              if (widget.onSave != null) ...<Widget>[
                const SizedBox(width: 8),
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
    );
  }
}

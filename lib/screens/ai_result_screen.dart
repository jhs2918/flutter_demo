import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// [02-03] AI가 생성한 문장을 보여주고 직접 수정한 뒤 복사할 수 있는 화면.
/// AI API 연동 전까지는 record_screen에서 선택 항목을 이어붙인 문장을 대신 받는다.
class AiResultScreen extends StatefulWidget {
  const AiResultScreen({super.key, required this.initialText});

  final String initialText;

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
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy),
              label: const Text('복사'),
            ),
          ),
        ),
      ),
    );
  }
}

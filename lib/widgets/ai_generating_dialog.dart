import 'package:flutter/material.dart';

/// [02-03][07] "AI 기록 생성" 버튼을 누른 뒤 백엔드 응답을 기다리는 동안
/// 보여주는 로딩 다이얼로그. 응답이 오거나 실패하면 record_screen이 직접 닫는다.
class AiGeneratingDialog extends StatelessWidget {
  const AiGeneratingDialog({super.key, this.message = 'AI 문장 작성 중...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 응답을 받기 전에는 뒤로가기로 닫을 수 없다.
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
}

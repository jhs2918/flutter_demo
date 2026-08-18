import 'package:flutter/material.dart';

import '../models/card_catalog.dart';
import '../theme/pastel_palette.dart';
import '../widgets/font_scale_bar.dart';
import 'record_type_select_screen.dart';

/// [낱말카드 개편 v2][1단계] 방문요양/주간보호 서비스 종류를 고른다. 등급
/// 선택 단계는 없고, 바로 기록유형 선택 화면으로 넘어간다.
class ServiceSelectScreen extends StatelessWidget {
  const ServiceSelectScreen({super.key});

  void _select(BuildContext context, CardService service) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            RecordTypeSelectScreen(service: service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('급여제공기록'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          const FontScaleBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text(
                    '어떤 서비스를 제공하시나요?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kCardTitleColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _ServiceButton(
                    label: '방문요양',
                    emoji: '🏠',
                    onTap: () => _select(context, CardService.visit),
                  ),
                  const SizedBox(height: 20),
                  _ServiceButton(
                    label: '주간보호',
                    emoji: '🏢',
                    onTap: () => _select(context, CardService.day),
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

class _ServiceButton extends StatelessWidget {
  const _ServiceButton({
    required this.label,
    required this.emoji,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kCardBorder, width: 2),
          ),
          child: Column(
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kCardTitleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

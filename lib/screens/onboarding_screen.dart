import 'package:flutter/material.dart';

import '../services/onboarding_preferences.dart';
import '../theme/pastel_palette.dart';

/// 사용법 안내 화면을 전체화면 모달로 띄운다. 앱 첫 실행 시 자동으로
/// 한 번 호출되고, 메인 화면의 "설명서" 버튼을 눌러도 같은 화면이 뜬다.
Future<void> showOnboardingScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext context) => const OnboardingScreen(),
    ),
  );
}

class _Step {
  const _Step({this.number, required this.icon, required this.text});

  final String? number;
  final IconData icon;
  final String text;
}

/// 앱 사용법을 큰 글자·아이콘·단계별 구성으로 설명하는 화면. 나이가 있는
/// 사용자도 부담 없이 읽을 수 있도록 화면을 채우는 큼직한 카드 레이아웃을
/// 쓴다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final OnboardingPreferences _prefs = OnboardingPreferences();
  bool _dontShowAgain = false;

  Future<void> _confirm() async {
    await _prefs.setDontShowAgain(_dontShowAgain);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('사용법 안내'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          children: const <Widget>[
            _StepSection(
              title: '이렇게 사용해요',
              steps: <_Step>[
                _Step(
                  number: '1',
                  icon: Icons.touch_app,
                  text: '카드를 눌러서 해당하는 단어를 골라요.',
                ),
                _Step(
                  number: '2',
                  icon: Icons.checklist,
                  text: '고른 단어들을 아래에서 확인해요.',
                ),
                _Step(
                  number: '3',
                  icon: Icons.auto_awesome,
                  text: '"AI로 작성하기"를 누르면 AI가 알아서 기록을 써줘요.',
                ),
              ],
            ),
            SizedBox(height: 24),
            _StepSection(
              title: '수정하거나 이어서 쓰고 싶을 때',
              steps: <_Step>[
                _Step(
                  icon: Icons.arrow_back,
                  text: '뒤로 가면 골랐던 단어를 바꿀 수 있어요.',
                ),
                _Step(
                  icon: Icons.swap_horiz,
                  text: 'AI 결과 화면에서 "다른 조치 선택하기"를 누르면 '
                      '조치만 다시 고를 수 있어요.',
                ),
                _Step(
                  icon: Icons.chat_bubble_outline,
                  text: '결과 화면 아래 채팅창에 "더 짧게 써줘"처럼 원하는 '
                      '대로 요청해서 이어서 다듬을 수 있어요.',
                ),
              ],
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CheckboxListTile(
                value: _dontShowAgain,
                onChanged: (bool? value) =>
                    setState(() => _dontShowAgain = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: kAccentPurple,
                title: const Text(
                  '다시 보지 않기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kCardTitleColor,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccentPurple,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepSection extends StatelessWidget {
  const _StepSection({required this.title, required this.steps});

  final String title;
  final List<_Step> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: kCardTitleColor,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < steps.length; i++) ...<Widget>[
            _StepRow(step: steps[i]),
            if (i != steps.length - 1) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: kWordButtonBg,
            shape: BoxShape.circle,
          ),
          child: step.number != null
              ? Text(
                  step.number!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kAccentPurple,
                  ),
                )
              : Icon(step.icon, color: kAccentPurple, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              step.text,
              style: const TextStyle(
                fontSize: 18,
                height: 1.4,
                color: kCardTitleColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

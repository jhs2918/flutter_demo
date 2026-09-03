import 'package:flutter/material.dart';

import '../models/card_catalog.dart';
import '../models/premium_tier.dart';
import '../services/onboarding_preferences.dart';
import '../state/purchase_controller.dart';
import '../theme/pastel_palette.dart';
import '../widgets/banner_ad_bar.dart';
import '../widgets/font_scale_bar.dart';
import 'card_select_screen.dart';
import 'onboarding_screen.dart';
import 'premium_screen.dart';

/// [상태변화일지 전용판] 방문요양/주간보호 서비스 종류를 고른다. 기록유형은
/// 상태변화일지 하나뿐이라 별도 선택 화면 없이 바로 카드 선택 화면으로
/// 넘어간다.
class ServiceSelectScreen extends StatefulWidget {
  const ServiceSelectScreen({super.key});

  @override
  State<ServiceSelectScreen> createState() => _ServiceSelectScreenState();
}

class _ServiceSelectScreenState extends State<ServiceSelectScreen> {
  final OnboardingPreferences _onboardingPrefs = OnboardingPreferences();

  @override
  void initState() {
    super.initState();
    // 앱을 처음 켰을 때(또는 "다시 보지 않기"를 아직 안 눌렀을 때) 사용법
    // 안내 화면을 자동으로 띄운다. build 도중에는 push할 수 없어 첫 프레임이
    // 그려진 뒤로 미룬다.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowOnboarding(),
    );
  }

  Future<void> _maybeShowOnboarding() async {
    final bool shouldShow = await _onboardingPrefs.shouldShowOnLaunch();
    if (!shouldShow || !mounted) return;
    await showOnboardingScreen(context);
  }

  void _select(CardService service) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CardSelectScreen(
          service: service,
          recordTypeId: 'status',
          recordTypeLabel: '상태변화일지',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [수익화] 무료 등급일 때만 상단 배너 광고를 보여준다. PurchaseScope를
    // 구독해두면 구매가 완료되는 순간 자동으로 다시 그려져 배너가 사라진다.
    final PremiumTier tier = PurchaseScope.of(context).tier;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('상태변화일지'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const PremiumScreen(),
              ),
            ),
            icon: const Icon(Icons.workspace_premium),
            tooltip: '프리미엄',
          ),
          // [온보딩] 언제든 다시 볼 수 있게 메인 화면 상단에 상시 노출.
          TextButton.icon(
            onPressed: () => showOnboardingScreen(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.menu_book),
            label: const Text(
              '설명서',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (tier == PremiumTier.free) const BannerAdBar(),
          const FontScaleBar(),
          Expanded(
            // [글자크기 확대 시 화면 밖으로 넘치는 문제 수정] 글자를 많이
            // 키우면 두 서비스 버튼 + 안내 문구가 세로로 화면보다 커질 수
            // 있다 - LayoutBuilder로 실제 남은 높이를 알아내 그보다 작을
            // 때만 가운데 정렬하고, 넘치면 스크롤해서 잘리지 않고 끝까지
            // 볼 수 있게 한다.
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
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
                          onTap: () => _select(CardService.visit),
                        ),
                        const SizedBox(height: 20),
                        _ServiceButton(
                          label: '주간보호',
                          emoji: '🏢',
                          onTap: () => _select(CardService.day),
                        ),
                      ],
                    ),
                  ),
                );
              },
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

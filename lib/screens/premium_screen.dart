import 'package:flutter/material.dart';

import '../models/premium_tier.dart';
import '../state/purchase_controller.dart';
import '../theme/pastel_palette.dart';

/// [수익화] 두 유료 등급을 소개하고 구매/복원할 수 있는 화면. 메인 화면
/// AppBar의 "프리미엄" 버튼으로 언제든 들어올 수 있다.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PurchaseController purchases = PurchaseScope.of(context);

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: const Text('프리미엄'),
        backgroundColor: kSectionHeaderBg,
        foregroundColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: purchases,
        builder: (BuildContext context, Widget? _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              const Text(
                '광고 없이 더 편하게 기록하세요',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kCardTitleColor,
                ),
              ),
              const SizedBox(height: 20),
              _PlanCard(
                title: '하루 30회 무료',
                description: '상단 배너 광고가 사라지고,\n하루 30회까지는 전면광고 없이 결과를 바로 봐요.',
                priceLabel: purchases.priceLabel(
                      PurchaseController.premium30ProductId,
                    ) ??
                    '5,000원',
                owned: purchases.tier == PremiumTier.premium30 ||
                    purchases.tier == PremiumTier.premium100,
                onBuy: () =>
                    purchases.buy(PurchaseController.premium30ProductId),
              ),
              const SizedBox(height: 16),
              _PlanCard(
                title: '하루 100회 무료',
                description: '상단 배너 광고가 사라지고,\n하루 100회까지는 전면광고 없이 결과를 바로 봐요.',
                priceLabel: purchases.priceLabel(
                      PurchaseController.premium100ProductId,
                    ) ??
                    '9,900원',
                owned: purchases.tier == PremiumTier.premium100,
                onBuy: () =>
                    purchases.buy(PurchaseController.premium100ProductId),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: purchases.restore,
                  child: const Text('이전에 구매한 내역 복원하기'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.owned,
    required this.onBuy,
  });

  final String title;
  final String description;
  final String priceLabel;
  final bool owned;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: owned ? kCardSelectedBorder : kCardBorder,
          width: owned ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kCardTitleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: kSubHeaderColor, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: owned ? null : onBuy,
              style: FilledButton.styleFrom(backgroundColor: kAccentPurple),
              child: Text(owned ? '이용 중' : '$priceLabel 구매하기'),
            ),
          ),
        ],
      ),
    );
  }
}

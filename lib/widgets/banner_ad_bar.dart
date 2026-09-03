import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// [수익화][테스트 ID] Google이 제공하는 공식 테스트 배너 단위 ID. 실제
// 배너 광고 단위를 AdMob 콘솔에서 만들면 이 값만 그 ID로 바꾸면 된다.
// 테스트 ID로 배포하면 무효 트래픽으로 계정이 제재될 수 있으니 출시 전
// 반드시 교체할 것.
const String _kBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

/// [수익화] 화면 상단에 붙는 배너 광고. 무료 등급 사용자에게만 보여줄지는
/// 호출하는 화면이 [PurchaseController]의 등급을 보고 결정한다(이 위젯은
/// 조건 없이 항상 배너를 불러와 보여준다).
class BannerAdBar extends StatefulWidget {
  const BannerAdBar({super.key});

  @override
  State<BannerAdBar> createState() => _BannerAdBarState();
}

class _BannerAdBarState extends State<BannerAdBar> {
  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _load();
  }

  void _load() {
    final BannerAd ad = BannerAd(
      adUnitId: _kBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) return;
          setState(() => _ad = ad as BannerAd);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) => ad.dispose(),
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

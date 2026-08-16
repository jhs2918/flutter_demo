import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// [AdMob] AI 문장 생성 로딩 중에 노출하는 전면광고를 미리 불러와 두었다가
/// 필요할 때 바로 보여준다. 광고 로드/표시에 실패해도 생성 흐름을 막지
/// 않도록 항상 조용히 실패를 흡수한다.
class InterstitialAdService {
  static const String _adUnitId = 'ca-app-pub-7024249117931090/6459013393';

  InterstitialAd? _ad;
  bool _isLoading = false;

  bool get isReady => _ad != null;

  // 다음에 보여줄 광고를 미리 불러온다. 이미 불러온 광고가 있거나 불러오는
  // 중이면 아무것도 하지 않는다.
  void preload() {
    if (_isLoading || _ad != null) return;
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _isLoading = false;
          _ad = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isLoading = false;
          _ad = null;
        },
      ),
    );
  }

  // 미리 불러온 광고가 있으면 보여주고 닫힐 때까지 기다린다. 준비된 광고가
  // 없으면(로드 실패/아직 로딩 중) 즉시 반환해 생성 흐름을 막지 않는다.
  // 보여준 뒤에는 다음 번을 위해 새 광고를 다시 미리 불러온다.
  Future<void> showIfReady() async {
    final InterstitialAd? ad = _ad;
    if (ad == null) return;
    _ad = null;

    final Completer<void> completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
        preload();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
        preload();
      },
    );

    try {
      await ad.show();
    } on Object {
      // show() 자체가 실패하면 콜백이 아예 안 올 수 있어, 여기서 직접 완료
      // 처리하지 않으면 생성 흐름이 영영 멈춰있게 된다.
      ad.dispose();
      if (!completer.isCompleted) completer.complete();
      preload();
    }
    await completer.future;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/premium_tier.dart';

/// [수익화] 인앱결제 상품 두 종류(하루 30회/100회 무료 등급)를 관리한다.
/// 구매 내역은 스토어가 최종 출처지만, 앱을 껐다 켰을 때 스토어 응답을
/// 기다리지 않고 바로 등급을 알 수 있도록 상품 ID 목록을 로컬에도
/// 캐시해둔다.
class PurchaseController extends ChangeNotifier {
  static const String premium30ProductId = 'premium_30';
  static const String premium100ProductId = 'premium_100';
  static const Set<String> productIds = <String>{
    premium30ProductId,
    premium100ProductId,
  };

  static const String _ownedPrefsKey = 'owned_product_ids';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Set<String> _owned = <String>{};
  List<ProductDetails> _products = <ProductDetails>[];
  bool _storeAvailable = false;

  PremiumTier get tier {
    if (_owned.contains(premium100ProductId)) return PremiumTier.premium100;
    if (_owned.contains(premium30ProductId)) return PremiumTier.premium30;
    return PremiumTier.free;
  }

  /// 스토어에서 불러온 상품이 있으면 그 현지화된 가격 문자열(예: "₩5,000")을,
  /// 아직 못 불러왔으면 null을 준다.
  String? priceLabel(String productId) {
    for (final ProductDetails product in _products) {
      if (product.id == productId) return product.price;
    }
    return null;
  }

  /// 앱 시작 시 한 번 호출한다: 로컬 캐시로 등급을 즉시 반영하고, 스토어
  /// 상품 정보를 불러오고, 구매 갱신을 계속 듣는다. 스토어 플러그인이 없는
  /// 플랫폼(웹·데스크톱 등)이나 스토어 연결 실패는 조용히 무시한다 - 로컬
  /// 캐시로 반영된 등급만으로도 앱은 정상 동작한다.
  Future<void> init() async {
    await _restoreOwnedFromPrefs();

    try {
      _storeAvailable = await _iap.isAvailable();
      if (!_storeAvailable) return;

      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription?.cancel(),
        onError: (Object _) {},
      );

      final ProductDetailsResponse response = await _iap.queryProductDetails(
        productIds,
      );
      _products = response.productDetails;

      // 재설치 등으로 로컬 캐시가 비어있을 수 있으니 스토어 쪽 구매 이력도
      // 한 번 확인한다. 결과는 purchaseStream으로 비동기 전달된다.
      unawaited(_iap.restorePurchases());
    } on Object {
      _storeAvailable = false;
    }
  }

  Future<void> buy(String productId) async {
    if (!_storeAvailable) return;
    ProductDetails? details;
    for (final ProductDetails product in _products) {
      if (product.id == productId) {
        details = product;
        break;
      }
    }
    if (details == null) return;
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  Future<void> restore() async {
    if (!_storeAvailable) return;
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    bool changed = false;
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (_owned.add(purchase.productID)) changed = true;
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
    if (changed) {
      await _persistOwned();
      notifyListeners();
    }
  }

  Future<void> _restoreOwnedFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _owned = (prefs.getStringList(_ownedPrefsKey) ?? const <String>[]).toSet();
  }

  Future<void> _persistOwned() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_ownedPrefsKey, _owned.toList());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// 어느 화면에서든 [PurchaseController]에 접근할 수 있게 하는 스코프.
/// [FontScaleScope]와 같은 방식으로 MaterialApp 바깥에 한 번만 씌워둔다.
class PurchaseScope extends InheritedNotifier<PurchaseController> {
  const PurchaseScope({
    super.key,
    required PurchaseController controller,
    required super.child,
  }) : super(notifier: controller);

  static PurchaseController of(BuildContext context) {
    final PurchaseScope? scope = context
        .dependOnInheritedWidgetOfExactType<PurchaseScope>();
    assert(scope != null, 'PurchaseScope가 트리 위쪽에 없습니다.');
    return scope!.notifier!;
  }
}

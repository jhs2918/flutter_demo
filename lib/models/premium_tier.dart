/// [수익화] 구매 등급. 무료 사용자는 광고를 항상 보고, 두 유료 등급은
/// 하루 무료 횟수(quota) 안에서는 광고 없이 쓰다가 초과하면 다시 광고를
/// 본다.
enum PremiumTier {
  free,
  premium30,
  premium100;

  /// 하루에 광고 없이 쓸 수 있는 횟수. free는 애초에 무료 횟수가 없다.
  int get dailyFreeQuota {
    switch (this) {
      case PremiumTier.free:
        return 0;
      case PremiumTier.premium30:
        return 30;
      case PremiumTier.premium100:
        return 100;
    }
  }
}

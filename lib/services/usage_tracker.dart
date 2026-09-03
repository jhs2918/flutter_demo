import 'package:shared_preferences/shared_preferences.dart';

import '../models/premium_tier.dart';

/// [수익화] 유료 등급 사용자의 "하루 무료 횟수" 사용량을 기기 로컬 날짜
/// 기준으로 추적한다. 기기 날짜가 바뀌면(자정이 지나면) 자동으로 0부터
/// 다시 센다. 무료(비구매) 사용자는 애초에 무료 횟수가 없어 이 카운트로
/// 매번 광고 여부를 가리지 않는다([isOverQuota]가 free는 항상 true).
class UsageTracker {
  static const String _dateKey = 'usage_date';
  static const String _countKey = 'usage_count';
  static const String _upgradePromptShownKey = 'upgrade_prompt_shown';

  String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// "AI 결과 확인" 1회를 오늘 사용량에 기록하고, 기록 후 오늘 누적
  /// 횟수를 반환한다.
  Future<int> recordUse() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String today = _todayKey();
    final String? savedDate = prefs.getString(_dateKey);
    int count = savedDate == today ? (prefs.getInt(_countKey) ?? 0) : 0;
    count += 1;
    await prefs.setString(_dateKey, today);
    await prefs.setInt(_countKey, count);
    return count;
  }

  /// 주어진 등급 기준으로, 오늘 [count]번째 사용이 무료 횟수를 넘어서
  /// 광고를 봐야 하는지.
  bool isOverQuota(PremiumTier tier, int count) {
    if (tier == PremiumTier.free) return true;
    return count > tier.dailyFreeQuota;
  }

  /// [premium_30 -> premium_100] 업그레이드 안내 다이얼로그를 이미
  /// 보여준 적 있는지(설치 기준 평생 1번만).
  Future<bool> hasShownUpgradePrompt() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_upgradePromptShownKey) ?? false;
  }

  Future<void> markUpgradePromptShown() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_upgradePromptShownKey, true);
  }
}

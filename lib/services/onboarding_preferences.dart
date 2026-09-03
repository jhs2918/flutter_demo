import 'package:shared_preferences/shared_preferences.dart';

/// 사용법 안내(온보딩) 화면을 "다시 보지 않기"로 설정했는지 기억한다.
class OnboardingPreferences {
  static const String _dontShowKey = 'onboarding_dont_show_again';

  /// 앱 실행 시 온보딩 화면을 자동으로 띄워야 하면 true.
  Future<bool> shouldShowOnLaunch() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_dontShowKey) ?? false);
  }

  Future<void> setDontShowAgain(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dontShowKey, value);
  }
}

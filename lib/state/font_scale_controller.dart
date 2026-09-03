import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [낱말카드 개편] 앱 전체 글자 크기 배율(80%~200%, 10% 단위). 바꿀 때마다
/// SharedPreferences에 저장해, 앱을 다시 열어도 마지막에 골랐던 배율이
/// 그대로 적용된다(main()에서 [restore]를 한 번 호출해 불러온다).
class FontScaleController extends ChangeNotifier {
  static const double min = 0.8;
  static const double max = 2.0;
  static const String _prefsKey = 'font_scale';

  double _scale = 1.0;
  double get scale => _scale;

  set scale(double value) {
    final double clamped = value.clamp(min, max);
    if (clamped == _scale) return;
    _scale = clamped;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (SharedPreferences prefs) => prefs.setDouble(_prefsKey, clamped),
    );
  }

  /// 앱 시작 시 저장된 배율을 불러와 반영한다.
  Future<void> restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final double? saved = prefs.getDouble(_prefsKey);
    if (saved == null) return;
    final double clamped = saved.clamp(min, max);
    if (clamped == _scale) return;
    _scale = clamped;
    notifyListeners();
  }
}

/// 어느 화면에서든 [FontScaleController]에 접근할 수 있게 하는 스코프.
/// MaterialApp 바깥(위)에 한 번만 씌워두면, 새 낱말카드 플로우의 모든
/// 화면(서비스 선택 → 등급 선택 → 카드 선택 → AI 결과)이 같은 컨트롤러를
/// 공유한다.
class FontScaleScope extends InheritedNotifier<FontScaleController> {
  const FontScaleScope({
    super.key,
    required FontScaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static FontScaleController of(BuildContext context) {
    final FontScaleScope? scope = context
        .dependOnInheritedWidgetOfExactType<FontScaleScope>();
    assert(scope != null, 'FontScaleScope가 트리 위쪽에 없습니다.');
    return scope!.notifier!;
  }
}

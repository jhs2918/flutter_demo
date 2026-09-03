import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'screens/service_select_screen.dart';
import 'state/font_scale_controller.dart';
import 'theme/pastel_palette.dart';

// 앱 진입점. [AdMob] 전면광고 SDK를 앱 시작 시 한 번 초기화해둔다. google_mobile_ads는
// 웹 플랫폼 구현체가 없어 웹에서 호출하면 MissingPluginException이 발생하므로
// 웹에서는 초기화 자체를 건너뛴다.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) MobileAds.instance.initialize();
  runApp(const CareRecorderApp());
}

/// 앱 최상위 위젯. 테마와 한국어 로케일을 설정하고 [상태변화일지 전용판] 서비스
/// 선택 화면부터 시작하는 플로우를 띄운다. [FontScaleScope]를 MaterialApp
/// 바깥에 둬서 서비스 선택→카드 선택→AI 결과 어느 화면에서 글자 크기를
/// 조절해도 전체에 즉시 반영된다.
class CareRecorderApp extends StatefulWidget {
  const CareRecorderApp({super.key});

  @override
  State<CareRecorderApp> createState() => _CareRecorderAppState();
}

class _CareRecorderAppState extends State<CareRecorderApp> {
  final FontScaleController _fontScaleController = FontScaleController();

  @override
  void initState() {
    super.initState();
    // 저장된 글자 크기 배율을 불러온다 - 로드가 끝나기 전엔 기본값(100%)으로
    // 잠깐 보이다가, 저장된 값이 있으면 즉시 그 값으로 바뀐다.
    _fontScaleController.restore();
  }

  @override
  void dispose() {
    _fontScaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FontScaleScope(
      controller: _fontScaleController,
      child: MaterialApp(
        title: '스마트요양일지 - 방문,주간보호 상태변화 AI작성도우미',
        // 날짜 선택기 등 머티리얼 위젯을 한국어로 표시하기 위한 델리게이트.
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // 한국어만 지원한다.
        supportedLocales: const <Locale>[Locale('ko')],
        locale: const Locale('ko'),
        // [전면개편] 파스텔 핑크·라벤더 톤으로 앱 전체 테마를 맞춘다.
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: kAccentPurple,
            surface: kAppBackground,
          ),
          scaffoldBackgroundColor: kAppBackground,
          appBarTheme: const AppBarTheme(centerTitle: false),
        ),
        // [낱말카드 개편] --font-scale 배율을 앱 전체 텍스트에 자동으로
        // 적용한다. 개별 위젯에 글자 크기를 하드코딩할 필요가 없다.
        builder: (BuildContext context, Widget? child) {
          return AnimatedBuilder(
            animation: _fontScaleController,
            builder: (BuildContext context, Widget? _) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(_fontScaleController.scale),
                ),
                child: child!,
              );
            },
          );
        },
        home: const ServiceSelectScreen(),
      ),
    );
  }
}

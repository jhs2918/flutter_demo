import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'screens/record_screen.dart';
import 'theme/pastel_palette.dart';

// 앱 진입점. [AdMob] 전면광고 SDK를 앱 시작 시 한 번 초기화해둔다.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const CareRecorderApp());
}

/// 앱 최상위 위젯. 테마와 한국어 로케일을 설정하고 [02] 기록작성화면을 바로 띄운다.
class CareRecorderApp extends StatelessWidget {
  const CareRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '방문요양 기록도우미',
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
      home: const RecordScreen(),
    );
  }
}

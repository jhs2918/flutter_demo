import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/record_screen.dart';

// 앱 진입점.
void main() {
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: const RecordScreen(),
    );
  }
}

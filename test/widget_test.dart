import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_demo/main.dart';

void main() {
  // 각 테스트 전에 SharedPreferences를 빈 값으로 초기화하여 저장소를 격리한다.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // 앱을 켜면 개인정보 입력 없이 바로 [02] 기록작성화면(16개 카테고리 탭)이 표시되는지 확인한다.
  testWidgets('앱을 실행하면 16개 카테고리 탭이 있는 기록 작성 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    expect(find.text('기록 작성'), findsOneWidget);
    expect(find.widgetWithText(Tab, '카테고리 1'), findsOneWidget);
    expect(find.widgetWithText(Tab, '카테고리 16'), findsOneWidget);
    expect(find.text('버튼 추가'), findsOneWidget);
    expect(find.text('기타 직접입력'), findsOneWidget);
  });

  // 버튼 추가 다이얼로그로 커스텀 버튼을 만들면 해당 카테고리 탭에 칩으로 나타나는지 확인한다.
  testWidgets('버튼 추가로 커스텀 버튼을 만들면 목록에 나타난다', (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('버튼 추가'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '식사 보조',
    );
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, '식사 보조'), findsOneWidget);
  });
}

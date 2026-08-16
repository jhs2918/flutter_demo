import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_demo/screens/record_screen.dart';

// [B] 검색 기능 위젯 테스트. adb 에뮬레이터는 한글 IME 주입이 안 되어(OS 레벨
// 한계) tester.enterText로 직접 텍스트를 주입해 검증한다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpRecordScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RecordScreen()));
    await tester.pumpAndSettle();
  }

  final Finder searchField = find.byKey(const Key('wordSearchField'));

  testWidgets('일반 텍스트 검색 시 결과 개수와 일치하는 버튼이 표시된다',
      (WidgetTester tester) async {
    await pumpRecordScreen(tester);

    await tester.enterText(searchField, '통증');
    await tester.pumpAndSettle();

    expect(find.textContaining('검색결과'), findsOneWidget);
    // "통증"을 부분 문자열로 포함하는 버튼만 결과에 포함되어야 한다.
    expect(find.widgetWithText(ActionChip, '통증없음'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '허리통증호소'), findsOneWidget);
    // "두통호소"는 "통증"을 포함하지 않으므로 결과에 없어야 한다.
    expect(find.widgetWithText(ActionChip, '두통호소'), findsNothing);
  });

  testWidgets('초성만 입력해도 초성이 일치하는 버튼이 검색된다',
      (WidgetTester tester) async {
    await pumpRecordScreen(tester);

    // "보행불안정"의 초성은 "ㅂㅎㅂㅇㅈ" → "ㅂㅎ"로 검색되어야 한다.
    await tester.enterText(searchField, 'ㅂㅎ');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, '보행불안정'), findsOneWidget);
  });

  testWidgets('검색 결과를 탭하면 선택되고 검색창이 비워진다', (WidgetTester tester) async {
    await pumpRecordScreen(tester);

    await tester.enterText(searchField, '두통호소');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, '두통호소'));
    await tester.pumpAndSettle();

    // 검색창이 비워져 결과 영역이 사라진다.
    expect(find.textContaining('검색결과'), findsNothing);
    // 하단 요약 바에 선택 카운터가 1/10로 반영된다.
    expect(find.text('선택한 항목 (1/10)'), findsOneWidget);
    // 해당 카테고리(통증)가 자동으로 펼쳐져 선택된 칩(FilterChip)이 보인다.
    expect(find.widgetWithText(FilterChip, '두통호소'), findsOneWidget);
  });

  testWidgets('검색 결과가 없으면 직접입력 버튼이 표시된다', (WidgetTester tester) async {
    await pumpRecordScreen(tester);

    await tester.enterText(searchField, 'zzz존재하지않는단어zzz');
    await tester.pumpAndSettle();

    expect(find.textContaining('검색결과 없음'), findsOneWidget);
    expect(find.textContaining('직접입력으로 추가'), findsOneWidget);
  });
}

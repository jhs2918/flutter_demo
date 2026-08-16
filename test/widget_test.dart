import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_demo/main.dart';

// [낱말카드 개편] 앱을 켜면 서비스 선택 → 등급 선택 → 카드 선택으로 이어지는
// 새 급여제공기록 플로우가 바로 뜨는지 확인한다.
void main() {
  testWidgets('앱을 실행하면 방문요양/주간보호 서비스 선택 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    expect(find.text('방문요양'), findsOneWidget);
    expect(find.text('주간보호'), findsOneWidget);
  });

  testWidgets('방문요양을 고르면 등급 선택 화면에 인지지원등급이 없다', (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('방문요양'));
    await tester.pumpAndSettle();

    expect(find.text('1등급'), findsOneWidget);
    await tester.ensureVisible(find.text('5등급'));
    await tester.pumpAndSettle();
    expect(find.text('5등급'), findsOneWidget);
    // 인지지원등급은 주간보호 전용이라 방문요양에서는 절대 노출되면 안 된다.
    expect(find.text('인지지원등급'), findsNothing);
  });

  testWidgets('주간보호를 고르면 등급 선택 화면에 인지지원등급이 있다', (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('주간보호'));
    await tester.pumpAndSettle();

    expect(find.text('인지지원등급'), findsOneWidget);
  });

  testWidgets('등급을 고르면 카드 선택 화면에 카테고리가 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('방문요양'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3등급'));
    await tester.pumpAndSettle();

    expect(find.textContaining('식사·영양'), findsOneWidget);
    expect(find.textContaining('신체기능'), findsOneWidget);
    // 주거환경 점검 카테고리는 방문요양 전용이라 방문요양을 골랐을 때 보여야 한다.
    expect(find.textContaining('주거환경'), findsOneWidget);
    expect(find.text('선택 항목 0개'), findsOneWidget);
  });

  testWidgets('주간보호로는 방문 전용 카테고리(주거환경 점검)가 보이지 않는다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('주간보호'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3등급'));
    await tester.pumpAndSettle();

    expect(find.textContaining('주거환경'), findsNothing);
  });
}

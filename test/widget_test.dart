import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_demo/main.dart';

// [낱말카드 개편 v2] 앱을 켜면 서비스 선택 → 기록유형 선택 → 카드 선택으로
// 이어지는 플로우가 바로 뜨는지 확인한다. 등급 선택 단계는 없다.
void main() {
  // 카드 선택 화면은 CustomCardItemRepository를 통해 SharedPreferences를
  // 읽으므로, 목 값을 미리 설정해두지 않으면 getInstance()가 끝없이 대기해
  // pumpAndSettle이 타임아웃난다.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('앱을 실행하면 방문요양/주간보호 서비스 선택 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    expect(find.text('방문요양'), findsOneWidget);
    expect(find.text('주간보호'), findsOneWidget);
  });

  testWidgets('서비스를 고르면 등급 선택 없이 바로 기록유형 5종이 표시된다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('방문요양'));
    await tester.pumpAndSettle();

    expect(find.text('급여제공기록'), findsOneWidget);
    expect(find.text('상태변화일지'), findsOneWidget);
    expect(find.text('업무수행일지'), findsOneWidget);
    await tester.ensureVisible(find.text('사례관리'));
    await tester.pumpAndSettle();
    expect(find.text('사례관리'), findsOneWidget);
    await tester.ensureVisible(find.text('직원상담'));
    await tester.pumpAndSettle();
    expect(find.text('직원상담'), findsOneWidget);
    // 등급 선택 화면은 더 이상 없다.
    expect(find.text('1등급'), findsNothing);
    expect(find.text('인지지원등급'), findsNothing);
  });

  testWidgets('방문요양·상태변화일지를 고르면 방문 전용 카테고리(가정환경)가 보인다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('방문요양'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('상태변화일지'));
    await tester.pumpAndSettle();

    expect(find.textContaining('피부상태'), findsOneWidget);
    expect(find.textContaining('가정환경'), findsOneWidget);
    expect(find.text('선택 항목 0개'), findsOneWidget);
    // 주간보호 전용 카테고리는 방문요양에서 보이면 안 된다.
    expect(find.textContaining('등원상태'), findsNothing);
  });

  testWidgets('주간보호·상태변화일지를 고르면 주간보호 전용 카테고리(등원상태)가 보인다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('주간보호'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('상태변화일지'));
    await tester.pumpAndSettle();

    expect(find.textContaining('등원상태'), findsOneWidget);
    // 방문요양 전용 카테고리는 주간보호에서 보이면 안 된다.
    expect(find.textContaining('가정환경'), findsNothing);
  });

  testWidgets('급여제공기록에서는 시설별로 다른 카테고리가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('주간보호'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('급여제공기록'));
    await tester.pumpAndSettle();

    // 주간보호 급여제공기록 전용 카테고리.
    expect(find.textContaining('이동서비스 송영'), findsOneWidget);
    expect(find.textContaining('간호 및 처치'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_demo/main.dart';

// [낱말카드 개편 v2] 앱을 켜면 서비스 선택 → 기록유형 선택 → 카드 선택으로
// 이어지는 플로우가 바로 뜨는지 확인한다. 등급 선택 단계는 없다.

// [기록유형 선택 화면] 서비스 선택 화면에서 탭하면 MaterialPageRoute
// 전환 애니메이션(기본 300ms)이 먼저 돌고, 그 다음 화면에서 cards.json을
// 비동기로 읽어오는 동안 무한 반복 애니메이션인 CircularProgressIndicator가
// 잠깐 뜬다. pumpAndSettle()은 "더 이상 예정된 프레임이 없을 때"까지
// 기다리는 방식이라 반복 애니메이션을 만나면 타임아웃나므로, 전환이 끝날
// 시간을 먼저 확보한 뒤 스피너가 사라질 때까지 정해진 횟수만 pump한다.
Future<void> _waitForSpinnerToClear(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350)); // 페이지 전환 애니메이션
  for (int i = 0; i < 50; i++) {
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('CircularProgressIndicator가 사라지지 않았습니다(로딩이 끝나지 않음).');
}

void main() {
  // 카드 선택 화면은 CustomCardItemRepository를 통해 SharedPreferences를
  // 읽으므로, 목 값을 미리 설정해두지 않으면 getInstance()가 끝없이 대기해
  // pumpAndSettle이 타임아웃난다. onboarding_dont_show_again을 미리 켜두지
  // 않으면 앱 실행 직후 사용법 안내 화면이 자동으로 뜨면서 서비스 선택
  // 화면의 텍스트를 못 찾아 실패한다.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_dont_show_again': true,
    });
  });

  testWidgets('앱을 실행하면 방문요양/주간보호 서비스 선택 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    expect(find.text('방문요양'), findsOneWidget);
    expect(find.text('주간보호'), findsOneWidget);
  });

  testWidgets('서비스를 고르면 등급 선택 없이 바로 기록유형 6종이 표시된다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('방문요양'));
    await tester.pump();
    await _waitForSpinnerToClear(tester);

    expect(find.text('급여제공기록'), findsOneWidget);
    expect(find.text('상태변화일지'), findsOneWidget);
    expect(find.text('업무수행일지'), findsOneWidget);
    await tester.ensureVisible(find.text('사례관리'));
    await tester.pumpAndSettle();
    expect(find.text('사례관리'), findsOneWidget);
    await tester.ensureVisible(find.text('직원상담'));
    await tester.pumpAndSettle();
    expect(find.text('직원상담'), findsOneWidget);
    // 방문요양에는 프로그램평가가 없다(주간보호 전용).
    expect(find.text('프로그램평가'), findsNothing);
    // 등급 선택 화면은 더 이상 없다.
    expect(find.text('1등급'), findsNothing);
    expect(find.text('인지지원등급'), findsNothing);
  });

  testWidgets('주간보호를 고르면 주간보호 전용 프로그램평가까지 6종이 표시된다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('주간보호'));
    await tester.pump();
    await _waitForSpinnerToClear(tester);

    expect(find.text('급여제공기록'), findsOneWidget);
    expect(find.text('상태변화일지'), findsOneWidget);
    expect(find.text('업무수행일지'), findsOneWidget);
    await tester.ensureVisible(find.text('프로그램평가'));
    await tester.pumpAndSettle();
    expect(find.text('프로그램평가'), findsOneWidget);
  });

  testWidgets('방문요양·상태변화일지를 고르면 방문 전용 카테고리(가정환경)가 보인다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('방문요양'));
    await tester.pump();
    await _waitForSpinnerToClear(tester);
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
    await tester.pump();
    await _waitForSpinnerToClear(tester);
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
    await tester.pump();
    await _waitForSpinnerToClear(tester);
    await tester.tap(find.text('급여제공기록'));
    await tester.pumpAndSettle();

    // 주간보호 급여제공기록 전용 카테고리.
    expect(find.textContaining('이동서비스 송영'), findsOneWidget);
    expect(find.textContaining('간호 및 처치'), findsOneWidget);
  });

  testWidgets('주간보호·프로그램평가를 고르면 프로그램 계획/운영기록 카테고리가 보인다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('주간보호'));
    await tester.pump();
    await _waitForSpinnerToClear(tester);
    await tester.ensureVisible(find.text('프로그램평가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('프로그램평가'));
    await tester.pumpAndSettle();

    expect(find.textContaining('프로그램 계획'), findsOneWidget);
    expect(find.textContaining('프로그램 운영기록'), findsOneWidget);
  });
}

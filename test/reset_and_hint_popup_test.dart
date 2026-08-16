import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_demo/screens/record_screen.dart';

// [D-A][D-B] 초기화 버튼과 "조치·대응" 카드 미선택 안내 팝업(선택하러 가기 /
// 계속 진행)을 검증한다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpRecordScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RecordScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> selectFirstButton(WidgetTester tester) async {
    await tester.ensureVisible(find.text('이동·보행'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이동·보행'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '자립보행'));
    await tester.pumpAndSettle();
  }

  testWidgets('[A] 선택 항목이 없으면 초기화 버튼이 비활성화된다',
      (WidgetTester tester) async {
    await pumpRecordScreen(tester);

    final TextButton resetButton = tester.widget(
      find.ancestor(of: find.text('🗑️'), matching: find.byType(TextButton)),
    );
    expect(resetButton.onPressed, isNull);
  });

  testWidgets('[A] 초기화 확인 다이얼로그에서 취소하면 선택이 유지된다',
      (WidgetTester tester) async {
    await pumpRecordScreen(tester);
    await selectFirstButton(tester);
    expect(find.text('선택한 항목 (1/10)'), findsOneWidget);

    await tester.tap(
      find.ancestor(of: find.text('🗑️'), matching: find.byType(TextButton)),
    );
    await tester.pumpAndSettle();
    expect(find.text('선택 항목을 모두 초기화할까요?'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('선택한 항목 (1/10)'), findsOneWidget);
  });

  testWidgets('[A] 초기화 확인 다이얼로그에서 확인하면 선택이 전부 지워진다',
      (WidgetTester tester) async {
    await pumpRecordScreen(tester);
    await selectFirstButton(tester);
    expect(find.text('선택한 항목 (1/10)'), findsOneWidget);

    await tester.tap(
      find.ancestor(of: find.text('🗑️'), matching: find.byType(TextButton)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('선택한 항목 (0/10)'), findsOneWidget);
  });

  testWidgets('[B] "조치·대응" 카드 미선택 상태에서 생성 시도하면 두 버튼짜리 팝업이 뜬다',
      (WidgetTester tester) async {
    await pumpRecordScreen(tester);
    await selectFirstButton(tester);

    await tester.tap(find.text('AI 기록 생성'));
    await tester.pumpAndSettle();

    expect(find.text('선택하러 가기'), findsOneWidget);
    expect(find.text('계속 진행'), findsOneWidget);
    expect(find.text('확인'), findsNothing);
  });

  testWidgets(
      '[B] "선택하러 가기"를 누르면 팝업이 닫히고 "조치·대응" 카드가 펼쳐지며 생성은 되지 않는다',
      (WidgetTester tester) async {
    await pumpRecordScreen(tester);
    await selectFirstButton(tester);

    await tester.tap(find.text('AI 기록 생성'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('선택하러 가기'));
    await tester.pumpAndSettle();

    // 팝업이 닫히고, 결과 화면으로 넘어가지 않고 기록 작성 화면에 그대로 있다.
    expect(find.text('선택하러 가기'), findsNothing);
    expect(find.text('AI 기록 결과'), findsNothing);
    expect(find.text('기록 작성'), findsOneWidget);
    // "조치·대응" 카드가 펼쳐져 세부 그룹이 보인다(목록 맨 아래쪽이라
    // 뷰포트가 기본 크기여도 문제없이 스크롤+펼침이 되는지도 함께 검증한다).
    expect(find.text('즉각신고·연락'), findsOneWidget);
  });

  testWidgets('[B] "계속 진행"을 누르면 팝업이 닫히고 생성 흐름이 이어진다',
      (WidgetTester tester) async {
    await pumpRecordScreen(tester);
    await selectFirstButton(tester);

    await tester.tap(find.text('AI 기록 생성'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('계속 진행'));
    // flutter test 환경에서는 실제 네트워크 대신 HttpClient가 즉시 400을
    // 반환하므로(프레임워크 기본 동작), pumpAndSettle로 힌트 팝업 닫힘 →
    // 로딩 다이얼로그 → 에러 스낵바까지 끝까지 안전하게 진행된다.
    await tester.pumpAndSettle();

    // 팝업이 닫혔다(힌트 게이트를 통과해 생성 흐름이 실제로 이어졌다는 증거).
    expect(find.text('선택하러 가기'), findsNothing);
    expect(find.text('계속 진행'), findsNothing);
    expect(find.text('AI 문장 작성 중...'), findsNothing);
    expect(find.text('잠시 후 다시 시도해주세요'), findsOneWidget);
  });
}

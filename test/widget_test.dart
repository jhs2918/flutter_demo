import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_demo/main.dart';

void main() {
  // 각 테스트 전에 SharedPreferences를 빈 값으로 초기화하여 저장소를 격리한다.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // [전면개편] 앱을 켜면 개인정보 입력 없이 바로 기록작성화면(5개 대분류 + 19개 카드)이
  // 표시되는지 확인한다. 카드를 펼치기 전에는 단어 선택 영역(버튼 추가 등)이 보이지 않는다.
  testWidgets('앱을 실행하면 5개 대분류와 카드형 소분류가 있는 기록 작성 화면이 표시된다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    expect(find.text('기록 작성'), findsOneWidget);
    expect(find.text('신체 증상'), findsOneWidget);
    expect(find.text('생활 기능'), findsOneWidget);
    expect(find.text('정서·인지'), findsOneWidget);
    expect(find.text('활력·투약'), findsOneWidget);
    expect(find.text('조치·기록'), findsOneWidget);
    expect(find.text('통증'), findsOneWidget);
    expect(find.text('기타'), findsOneWidget);
    // 아직 어떤 카드도 펼치지 않았으므로 단어 선택 영역은 보이지 않는다.
    expect(find.text('버튼 추가'), findsNothing);
    expect(find.text('기타 직접입력'), findsNothing);
  });

  // 카드를 펼친 뒤 "버튼 추가"로 커스텀 버튼을 만들면 해당 세부 그룹에 칩으로 나타나는지 확인한다.
  testWidgets('카드를 펼치고 버튼 추가로 커스텀 버튼을 만들면 목록에 나타난다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CareRecorderApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('이동·보행'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이동·보행'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('버튼 추가').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('버튼 추가').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '보행 보조',
    );
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, '보행 보조'), findsOneWidget);
  });
}

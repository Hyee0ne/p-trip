import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/features/my/data_sources_sheet.dart';
import 'package:p_trip/features/my/my_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 출처표시는 **의무**다 (공공누리). 관광공사 사진·개요를 그대로 띄우는 앱이라
/// 스토어 설명이 아니라 앱 안에서 밝혀야 한다. 이 테스트가 그걸 지킨다.
///
/// 화살표만 있고 안 눌리는 행은 애플이 '비활성 UI 요소'로 반려한다 —
/// 그것도 같이 잠근다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpMy(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: MyScreen())),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  test('출처 목록이 비어 있지 않다 — 지우면 라이선스 위반이다', () {
    expect(S.sources, isNotEmpty);
    for (final s in S.sources) {
      expect(s.org.trim(), isNotEmpty, reason: '제공기관 이름이 비었다');
      expect(s.what.trim(), isNotEmpty, reason: '데이터셋 이름이 비었다');
    }
  });

  test('관광공사가 출처에 있다 — 사진과 개요를 그대로 쓴다', () {
    expect(S.sources.map((s) => s.org), contains('한국관광공사'));
  });

  testWidgets('설정에 「데이터 출처」가 있고, 누르면 기관들이 나온다', (tester) async {
    await pumpMy(tester);

    final row = find.text(S.sourcesRow);
    await tester.scrollUntilVisible(row, 300);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(DataSourcesSheet), findsOneWidget);
    expect(find.text(S.sourcesIntro), findsOneWidget);
    for (final s in S.sources) {
      expect(find.text(s.org), findsOneWidget, reason: '${s.org} 가 시트에 없다');
    }
    // 사진 저작권이 우리 것이 아니라는 말도 함께 있어야 한다.
    expect(find.text(S.sourcesNote), findsOneWidget);
  });

  testWidgets('화살표를 단 설정 행은 전부 눌린다 — 죽은 행이 없다', (tester) async {
    await pumpMy(tester);

    for (final label in [S.photoAccessRow, S.sourcesRow]) {
      final row = find.text(label);
      await tester.scrollUntilVisible(row, 300);
      // 화살표가 붙은 행은 InkWell 안에 있어야 한다 (onTap이 있다는 뜻).
      expect(
        find.ancestor(of: row, matching: find.byType(InkWell)),
        findsOneWidget,
        reason: '「$label」 행에 onTap이 없다 — 애플이 비활성 요소로 반려한다',
      );
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/widgets/chips.dart';
import 'package:p_trip/core/view_mode.dart';
import 'package:p_trip/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PTripApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('3탭 셸이 뜨고 발견 탭이 기본 선택된다', (tester) async {
    await pumpApp(tester);
    expect(find.text(S.tabDiscover), findsOneWidget);
    expect(find.text(S.tabRadar), findsOneWidget);
    expect(find.text(S.tabMy), findsOneWidget);
    expect(find.text(S.appName), findsOneWidget);
  });

  testWidgets('레이더 탭으로 전환하면 DR-01이 뜬다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(S.tabRadar));
    await tester.pumpAndSettle();
    expect(find.text('DR-01'), findsOneWidget);
  });

  testWidgets('홈 기본 모드는 한 곳씩이고, 오늘의 발견이 전면 카드로 뜬다', (tester) async {
    await pumpApp(tester);
    expect(find.text(S.viewOneByOne), findsOneWidget);
    // 픽스처의 오늘 축 스팟 (실존 — CLAUDE.md 데모 기준 데이터)
    expect(find.text('북평 5일장'), findsOneWidget);
  });

  testWidgets('토글하면 훑어보기로 바뀌고 검색창과 필터가 나타난다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    expect(find.text(S.viewBrowse), findsOneWidget);
    expect(find.text(S.searchHint), findsOneWidget);
    // 필터는 밖에 둘이만 (§0.2).
    // ⚠ '오늘만'은 시의성 배지 라벨과 글자가 같으므로 위젯 타입으로 좁힌다.
    expect(find.widgetWithText(DiscoverFilterChip, S.filterToday), findsOneWidget);
    expect(find.widgetWithText(DiscoverFilterChip, S.filterNear), findsOneWidget);
    expect(find.byType(FilterMoreChip), findsOneWidget);
  });

  testWidgets('변화율을 못 내는 축은 섹션을 통째로 숨긴다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    // 픽스처가 변화율을 지어내지 않으므로 두 섹션은 그려지지 않아야 한다
    expect(find.text(S.secToday), findsOneWidget);
    expect(find.text(S.secRising), findsNothing);
    expect(find.text(S.secTracks), findsNothing);
  });

  test('뷰 모드 기본값은 한 곳씩', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(viewModeProvider), ViewMode.oneByOne);
    c.read(viewModeProvider.notifier).toggle();
    expect(c.read(viewModeProvider), ViewMode.browse);
  });
}

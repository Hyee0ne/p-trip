import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/main.dart';

/// 발견 탭 화면 간 이동이 실제로 되는지 — 라우트 선언만으로는 안 잡히는 것.
void main() {
  /// ⚠ CO-07에서는 pumpAndSettle을 쓸 수 없다. 위치를 재는 동안 스피너가 돌고,
  ///   테스트 환경에선 geolocator 채널이 응답하지 않아 영원히 돈다.
  ///   실기기에서는 8초 타임아웃이 걸려 있어 멈춘다.
  Future<void> settleRoutes(WidgetTester tester) async {
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: PTripApp()));
    // ⚠ 홈 스토리 덱이 자동으로 넘어가므로 pumpAndSettle을 쓸 수 없다
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> toBrowse(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
  }

  /// 훑어보기 하단의 국도 레일까지 끌어내려 '전체 51'을 누른다.
  /// 큐레이션 섹션이 늘어나면 화면 밖으로 밀리므로 항상 스크롤 후 탭한다.
  Future<void> toRoutes(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.text('전체 51'),
      find.byKey(const Key('browse-list')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 51'));
    await settleRoutes(tester);
  }

  /// 바텀시트를 끌어올린다 — 이 화면의 '모드 전환'이 곧 이 제스처다.
  Future<void> pullSheetUp(WidgetTester tester) async {
    await tester.drag(find.byKey(const Key('routes-sheet-list')), const Offset(0, -520));
    await settleRoutes(tester);
  }

  /// 시트 안에서 노선 줄을 찾아 탭한다. 51줄이라 화면 밖으로 나간다.
  /// 코스는 이제 **시트 맨 아래 한 줄**로 들어간다 (CO-01 재설계).
  /// 주 흐름은 국도 → 방향이고, 코스는 "처음이라 걱정되면" 쪽이다.
  Future<void> toCourse(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.text(S.routesCourseHint),
      find.byKey(const Key('routes-sheet-list')),
      const Offset(0, -120),
    );
    await settleRoutes(tester);
    await tester.tap(find.text(S.routesCourseHint));
    await tester.pumpAndSettle();
  }

  Future<void> tapRoute(WidgetTester tester, String name) async {
    await tester.dragUntilVisible(
      find.text(name),
      find.byKey(const Key('routes-sheet-list')),
      const Offset(0, -120),
    );
    await settleRoutes(tester);
    await tester.tap(find.text(name));
    // ⚠ CO-07 지도 화면은 계속 그려서 pumpAndSettle이 안 끝난다 (그래서 settleRoutes가 있다).
    //   노선을 탭하면 그 위에 CO-08 시트가 얹히므로 여기서도 같은 방식으로 기다린다.
    await settleRoutes(tester);
  }

  testWidgets('홈 → 국도 선택(CO-07): 지도 + 바텀시트, 주행 불가 노선 문구', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);

    await toRoutes(tester);

    // 접힘: 지도가 주인공이고 시트는 '여기서 탈 수 있는 길'만 말한다
    expect(find.text(S.routesNearTitle), findsOneWidget);
    expect(find.text(S.routesAllCta), findsOneWidget);
    expect(find.text(S.routesTitle), findsNothing);
    // 제목은 시트가 갖는다 — 앱바에 같은 말을 또 쓰지 않는다
    expect(find.descendant(of: find.byType(AppBar), matching: find.byType(Text)), findsNothing);

    // 끌어올림: 같은 화면이 51선 전체가 된다. 토글이 아니다
    await pullSheetUp(tester);
    expect(find.text(S.routesTitle), findsOneWidget);
    expect(find.text('${S.routesSub} · 총 14,000km'), findsOneWidget);
    expect(find.text('남북(홀수)'), findsOneWidget);
    // 북한 구간은 별명 대신 고정 문구 (SCREENS.md CO-07)
    expect(find.text(S.routeUndrivable), findsOneWidget);
  });

  testWidgets('국도를 고르면 방향만 묻는다 (CO-08) — 코스로 빠지지 않는다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await toRoutes(tester);

    await tapRoute(tester, '동해 바닷길');

    // ⚠ 길을 골랐는데 다시 코스를 고르게 하면 결국 목적지를 정하는 흐름이고,
    //   그게 내비 문법이다 (CO-01 재설계).
    expect(find.text(S.departWhichWay), findsOneWidget);
    expect(find.text(S.departNorth), findsOneWidget);
    expect(find.text(S.departSouth), findsOneWidget);

    // 목적지를 묻지 않는다는 걸 화면이 직접 말한다
    expect(find.text(S.departNoDestination), findsOneWidget);

    // 코스 상세로 새지 않았다
    expect(find.text(S.courseStart), findsNothing);
    expect(find.text('순수 주행시간'), findsNothing);
  });

  testWidgets('스팟 상세(CO-03): 확신도 문구가 있고 별점은 없다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);

    await tester.tap(find.text('북평 5일장').first);
    await tester.pumpAndSettle();

    expect(find.text(S.trustNotice), findsOneWidget);
    expect(find.text(S.trustCall), findsOneWidget);
    expect(find.text(S.trustReviews), findsOneWidget);
    expect(find.text(S.spotNavigate), findsOneWidget);
    // ⚠ 원칙 3 — 별점 위젯이 존재하면 안 된다
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_half), findsNothing);
  });

  testWidgets('검색(SR)은 별도 화면 — 토글이 사라지고 탭바를 덮는다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);

    await tester.tap(find.text(S.searchHint));
    await tester.pumpAndSettle();

    // 신호 3: 토글 없음 + 탭바 덮음
    expect(find.text(S.viewBrowse), findsNothing);
    expect(find.text(S.tabRadar), findsNothing);
    // 입력 전 화면
    // ⚠ '최근 검색'은 **처음 켠 앱에 없는 게 맞다.** 전에는 가짜 기록을 심어두고
    //   그게 보이는지 검사하고 있었다 — 없는 걸 있다고 검증하던 셈이다.
    expect(find.text(S.searchRecent), findsNothing);
    expect(find.text(S.searchSuggest), findsOneWidget);
  });

  testWidgets('검색하면 그때부터 최근 검색이 생긴다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await tester.tap(find.text(S.searchHint));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '물회');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // 검색 중에는 결과가 보인다. 입력을 비워야 입력 전 화면으로 돌아온다.
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.text(S.searchRecent), findsOneWidget);
    expect(find.text('물회'), findsWidgets);
  });

  testWidgets('검색어를 넣으면 결과가 리스트로 나온다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await tester.tap(find.text(S.searchHint));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '물회');
    await tester.pumpAndSettle();

    expect(find.text('1곳'), findsOneWidget);
    expect(find.text('어달마을 물회 골목'), findsOneWidget);
  });

  testWidgets('없는 걸 검색하면 억지로 채우지 않는다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await tester.tap(find.text(S.searchHint));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '스키장');
    await tester.pumpAndSettle();

    expect(find.text(S.searchEmpty('스키장')), findsOneWidget);
    expect(find.text('북평 5일장'), findsNothing);
  });

  // ── M2 나머지 ─────────────────────────────────────────────

  testWidgets('하트를 누르면 찜에 담기고 토스트가 뜬다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);

    expect(find.byIcon(Icons.favorite), findsNothing);
    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsWidgets);
    expect(find.text(S.toastSaved), findsOneWidget);
  });

  testWidgets('찜 상태는 화면이 바뀌어도 유지된다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('북평 5일장').first);
    await tester.pumpAndSettle();

    // CO-03 상단 하트도 같은 상태를 본다
    expect(find.byIcon(Icons.favorite), findsWidgets);
  });

  testWidgets('거점 없이 출발하면 강제하지 않고 CO-06으로 유도한다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await toRoutes(tester);
    await toCourse(tester);

    await tester.tap(find.text(S.courseStart));
    await tester.pumpAndSettle();

    expect(find.text(S.baseTitle), findsOneWidget);
    expect(find.text(S.baseIntro), findsOneWidget);

    // ⚠ 거점은 **선택사항**이다 (원칙 4). 여기서 나가는 길이 반드시 있어야 한다.
    //   이 버튼이 없으면 거점을 안 정한 사람은 영영 출발을 못 한다.
    expect(find.text(S.baseSkipAndStart), findsOneWidget);
    await tester.tap(find.text(S.baseSkipAndStart));
    // 레이더는 스윕이 계속 돌아 pumpAndSettle이 끝나지 않는다.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text(S.radarFinish), findsWidgets, reason: '거점 없이도 레이더로 들어가야 한다');
  });

  testWidgets('거점은 위치만 받는다 — 예약 버튼은 외부 링크', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await toRoutes(tester);
    await toCourse(tester);
    await tester.tap(find.text(S.baseNone));
    await tester.pumpAndSettle();

    expect(find.text(S.baseCandidatesSub), findsOneWidget);
    expect(find.text(S.baseWithout), findsOneWidget);
    // 아무것도 안 고르고 확정하면 막는다
    await tester.tap(find.text(S.baseCta));
    await tester.pumpAndSettle();
    expect(find.text(S.baseToastPickFirst), findsOneWidget);
  });

  testWidgets('스팟 길 안내 → HND 시트. 무료도로 안내가 있다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await tester.tap(find.text('북평 5일장').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.spotNavigate));
    await tester.pumpAndSettle();

    expect(find.text(S.handoffKakao), findsOneWidget);
    expect(find.text(S.handoffTmap), findsOneWidget);
    expect(find.text(S.handoffFreeRoad), findsOneWidget);
  });
}

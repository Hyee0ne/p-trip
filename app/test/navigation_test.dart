import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:p_trip/core/location.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/widgets/app_tab_bar.dart';
import 'package:p_trip/core/widgets/cards.dart';
import 'package:p_trip/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ⚠ 저장소가 파일 내내 공유된다. 최근 검색·찜이 앞 테스트에서 넘어오면
  //   뒤 테스트가 이유 없이 흔들린다.
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  /// ⚠ **홈이 곧 지도다** (2026-08-30 재설계). 예전엔 홈 → 훑어보기 → '전체 51'을
  ///   거쳐야 여기 왔는데, 이제 앱을 켜면 바로 이 화면이다.
  Future<void> toRoutes(WidgetTester tester) async {
    await settleRoutes(tester);
  }

  /// 스팟으로 가는 길. ⚠ 옛 홈의 큐레이션 목록이 없어져서(2026-08-30 재설계)
  /// 이제 **검색**이 스팟에 닿는 문이다.
  Future<void> toSpot(WidgetTester tester, String name) async {
    await settleRoutes(tester);
    // ⚠ 홈(지도)이 뒤에서 계속 그려서 pumpAndSettle이 제대로 안 끝난다.
    await tester.tap(find.text(S.searchHint));
    await settleRoutes(tester);
    await tester.enterText(find.byType(TextField), name);
    await settleRoutes(tester);
    // ⚠ 입력창에도 같은 글자가 있다. 결과 행(SpotListRow)만 정확히 집는다.
    await tester.tap(find.widgetWithText(SpotListRow, name));
    await settleRoutes(tester);
  }

  /// 바텀시트를 끌어올린다 — 이 화면의 '모드 전환'이 곧 이 제스처다.
  Future<void> pullSheetUp(WidgetTester tester) async {
    await tester.drag(find.byKey(const Key('routes-sheet-list')), const Offset(0, -520));
    await settleRoutes(tester);
  }

  /// 코스 화면으로. ⚠ 홈의 「처음이라 걱정되면, 짜여진 코스로」 줄은 지웠다 (2026-09-09) —
  ///   코스 화면 자체는 남아 있어 라우터로 바로 간다.
  Future<void> toCourse(WidgetTester tester) async {
    // 픽스처의 첫 코스(한계령길). 데모 코스 id 는 서버 것이라 픽스처엔 없다.
    GoRouter.of(tester.element(find.byType(AppTabBar))).go('/course/hangyeryeong');
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

    await toSpot(tester, '북평 5일장');

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
    // ⚠ 홈이 지도라 뜨는 데 프레임이 걸린다. 바로 누르면 아직 없다.
    await settleRoutes(tester);

    await tester.tap(find.text(S.searchHint));
    await tester.pumpAndSettle();

    // 검색은 탭바를 덮는 별도 화면이다 (§SR).
    expect(find.text(S.tabRadar), findsNothing);
    // 입력 전 화면
    // ⚠ '최근 검색'은 **처음 켠 앱에 없는 게 맞다.** 전에는 가짜 기록을 심어두고
    //   그게 보이는지 검사하고 있었다 — 없는 걸 있다고 검증하던 셈이다.
    expect(find.text(S.searchRecent), findsNothing);
    expect(find.text(S.searchSuggest), findsOneWidget);
  });

  testWidgets('검색하면 그때부터 최근 검색이 생긴다', (tester) async {
    await pumpApp(tester);
    await settleRoutes(tester);
    // ⚠ 홈(지도)이 뒤에서 계속 그려서 pumpAndSettle이 제대로 안 끝난다.
    await tester.tap(find.text(S.searchHint));
    await settleRoutes(tester);

    await tester.enterText(find.byType(TextField), '물회');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // 검색 중에는 결과가 보인다. 입력을 비워야 입력 전 화면으로 돌아온다.
    await tester.enterText(find.byType(TextField), '');
    await settleRoutes(tester);

    expect(find.text(S.searchRecent), findsOneWidget);
    expect(find.text('물회'), findsWidgets);
  });

  testWidgets('검색어를 넣으면 결과가 리스트로 나온다', (tester) async {
    await pumpApp(tester);
    await settleRoutes(tester);
    // ⚠ 홈(지도)이 뒤에서 계속 그려서 pumpAndSettle이 제대로 안 끝난다.
    await tester.tap(find.text(S.searchHint));
    await settleRoutes(tester);

    await tester.enterText(find.byType(TextField), '물회');
    await settleRoutes(tester);

    expect(find.text('1곳'), findsOneWidget);
    expect(find.text('어달마을 물회 골목'), findsOneWidget);
  });

  testWidgets('없는 걸 검색하면 억지로 채우지 않는다', (tester) async {
    await pumpApp(tester);
    await settleRoutes(tester);
    // ⚠ 홈(지도)이 뒤에서 계속 그려서 pumpAndSettle이 제대로 안 끝난다.
    await tester.tap(find.text(S.searchHint));
    await settleRoutes(tester);

    await tester.enterText(find.byType(TextField), '스키장');
    await tester.pumpAndSettle();

    expect(find.text(S.searchEmpty('스키장')), findsOneWidget);
    expect(find.text('북평 5일장'), findsNothing);
  });

  // ── M2 나머지 ─────────────────────────────────────────────

  testWidgets('하트를 누르면 찜에 담기고 토스트가 뜬다', (tester) async {
    await pumpApp(tester);
    // ⚠ 옛 홈 카드의 하트가 없어졌다 (2026-08-30 재설계). 하트는 스팟 상세에 있다.
    await toSpot(tester, '북평 5일장');

    expect(find.byIcon(Icons.favorite), findsNothing);
    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsWidgets);
    expect(find.text(S.toastSaved), findsOneWidget);
  });

  testWidgets('찜 상태는 화면이 바뀌어도 유지된다', (tester) async {
    await pumpApp(tester);
    await toSpot(tester, '북평 5일장');
    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await settleRoutes(tester);

    // 나갔다 다시 들어와도 같은 상태를 본다.
    // ⚠ CO-03은 Cupertino 뒤로가기가 아니라 우리 아이콘 버튼을 쓴다.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new).first);
    await settleRoutes(tester);
    await tester.tap(find.widgetWithText(SpotListRow, '북평 5일장'));
    await settleRoutes(tester);

    expect(find.byIcon(Icons.favorite), findsWidgets);
  });

  /// ⚠ 거점을 없앴다 (2026-09-07). 전에는 출발이 거점 화면(CO-06)으로 새고,
  ///   거점이 목적지였다. 이제 코스 출발은 **노선 출발과 같은 문법**이다 —
  ///   진입점까지 데려다주고 레이더로 넘긴다.
  testWidgets('코스 출발 — 거점을 거치지 않고 바로 레이더로 간다', (tester) async {
    await pumpApp(tester);
    await toRoutes(tester);
    await toCourse(tester);

    await tester.tap(find.text(S.courseStart));
    // 레이더는 스윕이 계속 돌아 pumpAndSettle 이 끝나지 않는다.
    // 위치 대기(3초)를 넘긴 뒤 레이더로 간다. 레이더는 스윕이 돌아 pumpAndSettle 이 안 끝난다.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text(S.radarFinish), findsWidgets, reason: '출발하면 레이더다');

    // ⚠ 발견 탭은 뿌리로 돌아가 있어야 한다 (2026-09-09). 코스 화면을 둔 채 탭만 바꾸면
    //   여행을 마치고 돌아왔을 때 그 화면이 그대로 있다.
    await tester.tap(
      find.descendant(of: find.byType(AppTabBar), matching: find.text(S.tabDiscover)),
    );
    await settleRoutes(tester);
    expect(find.text(S.courseStart), findsNothing, reason: '코스 화면은 내려갔다');
    // 시트는 펼친 채 남아 있을 수 있다(그 화면의 상태다). 뿌리 화면인지만 본다.
    expect(find.byKey(const Key('routes-sheet-list')), findsOneWidget, reason: '발견 탭은 국도 목록(뿌리)');
  });

  /// 실기기에서 잡은 것 (2026-09-09): 「길 떠나기」 시트는 발견 탭 내비게이터 위에 떠 있어서,
  /// 레이더로 탭만 바꾸면 `_busy`(버튼 비활성)인 채 남았다. 여행을 마치고 발견 탭에 오면
  /// 죽은 버튼이 기다리고 있었다.
  testWidgets('노선 출발 — 시트는 닫히고 발견 탭은 뿌리로. 다시 열면 버튼이 살아 있다', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 시트는 좌표가 있어야 출발시킨다 — 테스트엔 geolocator 가 없으니 하나 준다.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLocationProvider.overrideWith(
            (ref) async => const LocFix(LocStatus.ready, lat: 37.52, lng: 129.11),
          ),
        ],
        child: const PTripApp(),
      ),
    );
    await toRoutes(tester);
    await tapRoute(tester, '동해 바닷길');
    expect(find.text(S.departWhichWay), findsOneWidget);

    await tester.tap(find.text(S.departNorth));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text(S.radarFinish), findsWidgets, reason: '출발하면 레이더다');

    await tester.tap(
      find.descendant(of: find.byType(AppTabBar), matching: find.text(S.tabDiscover)),
    );
    await settleRoutes(tester);
    expect(find.text(S.departWhichWay), findsNothing, reason: '시트는 닫혔다');
    expect(find.text(S.routesNearTitle), findsOneWidget, reason: '발견 탭은 국도 목록(뿌리)');

    // 다시 열면 새 시트다 — 버튼이 눌린다.
    await tapRoute(tester, '동해 바닷길');
    final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, S.departNorth));
    expect(btn.enabled, isTrue, reason: '비활성인 채 남은 옛 시트가 아니다');
  });

  testWidgets('스팟 길 안내 → HND 시트. 무료도로 안내가 있다', (tester) async {
    await pumpApp(tester);
    await toSpot(tester, '북평 5일장');

    await tester.tap(find.text(S.spotNavigate));
    await tester.pumpAndSettle();

    expect(find.text(S.handoffTmap), findsOneWidget);
    // ⚠ 애플 지도를 빼면 심사에서 반려된다 (Guideline 4). 티맵은 뺐다 (2026-09-08).
    expect(find.text(S.handoffApple), findsOneWidget);
    expect(find.text(S.handoffFreeRoad), findsOneWidget);
  });
}

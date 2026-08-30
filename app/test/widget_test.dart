import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/saves.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/widgets/chips.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/data/repositories/discover_repository.dart';
import 'package:p_trip/data/repositories/fixture_discover_repository.dart';
import 'package:p_trip/data/repositories/providers.dart';
import 'package:p_trip/features/radar/radar_view.dart';
import 'package:p_trip/core/view_mode.dart';
import 'package:p_trip/main.dart';

void main() {
  /// ⚠ 홈의 스토리 덱은 7초마다 자동으로 넘어간다 — 끝나지 않는 애니메이션이라
  ///   `pumpAndSettle`을 쓰면 영원히 안 끝난다. 프레임을 몇 개만 돌린다.
  Future<void> settleHome(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PTripApp()));
    await settleHome(tester);
  }

  testWidgets('3탭 셸이 뜨고 발견 탭이 기본 선택된다', (tester) async {
    await pumpApp(tester);
    expect(find.text(S.tabDiscover), findsOneWidget);
    expect(find.text(S.tabRadar), findsOneWidget);
    expect(find.text(S.tabMy), findsOneWidget);
    expect(find.text(S.appName), findsOneWidget);
  });

  testWidgets('레이더 탭 — 경로가 아니라 주변 기준이라는 문구가 있다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(S.tabRadar));
    // ⚠ 레이더 스윕이 repeat 애니메이션이라 pumpAndSettle이 끝나지 않는다.
    //   프레임을 몇 번만 돌려 라우트 전환을 완료시킨다.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.text(S.radarScanning), findsOneWidget);
    // 레이더 뷰가 실제로 그려졌는지 (문구는 접혀 있을 수 있어 위젯으로 확인)
    expect(find.byType(RadarView), findsOneWidget);
    // ⚠ 레이더에는 뷰 토글이 없다 — 운전 중엔 언제나 한 곳씩
    expect(find.text(S.viewBrowse), findsNothing);
    expect(find.text(S.viewOneByOne), findsNothing);
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

  testWidgets('훑어보기에 큐레이션 3축이 모두 그려진다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    expect(find.text(S.secToday), findsOneWidget);
    // 아래 두 축은 스크롤해야 보인다
    for (final section in [S.secRising, S.secTracks]) {
      await tester.dragUntilVisible(
        find.text(section),
        find.byKey(const Key('browse-list')),
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      expect(find.text(section), findsOneWidget);
    }
  });

  testWidgets('데이터가 없는 축은 섹션을 통째로 숨긴다', (tester) async {
    // 빈 결과를 주는 레포로 갈아끼워 숨김 동작을 직접 검증한다
    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoverRepositoryProvider.overrideWith((ref) => const _EmptyRepo())],
        child: const PTripApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    expect(find.text(S.secToday), findsNothing);
    expect(find.text(S.secRising), findsNothing);
    expect(find.text(S.secTracks), findsNothing);
  });

  test('국도는 51선이고 남북 27 · 동서 24로 갈린다', () async {
    const repo = FixtureDiscoverRepository();
    final routes = await repo.routes();

    expect(routes.length, 51, reason: '국도 51선');
    expect(routes.where((r) => r.axis == 'NS').length, 27, reason: '남북(홀수)');
    expect(routes.where((r) => r.axis == 'EW').length, 24, reason: '동서(짝수)');

    // 홀수=남북, 짝수=동서는 규칙이다
    for (final r in routes) {
      expect(r.axis, r.id.isOdd ? 'NS' : 'EW', reason: '${r.id}번');
    }
    // 번호 중복 없음
    expect(routes.map((r) => r.id).toSet().length, 51);
  });

  test('찜은 스팟·코스·노선을 모두 담는다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(savesProvider.notifier);

    expect(n.toggleLike(const SaveRef.spot('bukpyeong-market')), isTrue);
    expect(n.toggleLike(const SaveRef.course('donghae-sea')), isTrue);
    expect(n.toggleLike(SaveRef.route(44)), isTrue);

    final s = c.read(savesProvider);
    expect(s.liked.length, 3);
    expect(s.idsOf(SaveTargetKind.spot), {'bukpyeong-market'});
    expect(s.idsOf(SaveTargetKind.course), {'donghae-sea'});
    expect(s.idsOf(SaveTargetKind.route), {'44'});

    // 같은 id라도 종류가 다르면 다른 항목이다
    expect(c.read(savesProvider).isLiked(const SaveRef.spot('donghae-sea')), isFalse);

    // 토글하면 빠진다
    expect(n.toggleLike(const SaveRef.course('donghae-sea')), isFalse);
    expect(c.read(savesProvider).idsOf(SaveTargetKind.course), isEmpty);
  });

  test('스쳐간 발견은 스팟에만 적립되고, 이미 찜한 곳은 내리지 않는다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(savesProvider.notifier);

    n.markPassed('chuam-chotdae');
    expect(c.read(savesProvider).isPassed('chuam-chotdae'), isTrue);

    n.toggleLike(const SaveRef.spot('mukho-lighthouse'));
    n.markPassed('mukho-lighthouse');
    expect(c.read(savesProvider).isPassed('mukho-lighthouse'), isFalse);
  });

  test('뷰 모드 기본값은 한 곳씩', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(viewModeProvider), ViewMode.oneByOne);
    c.read(viewModeProvider.notifier).toggle();
    expect(c.read(viewModeProvider), ViewMode.browse);
  });
}

/// 전부 빈 결과를 주는 레포 — "데이터 없으면 섹션을 숨긴다" 검증용.
class _EmptyRepo implements DiscoverRepository {
  const _EmptyRepo();
  @override
  Future<List<Spot>> spots({CurationAxis? axis, int? routeId}) async => const [];
  @override
  Future<List<RouteLine>> routes() async => const [];

  @override
  Future<NearbyResult> nearbyRoutes({required double lat, required double lng}) async =>
      const NearbyResult([], covered: true);

  @override
  Future<List<GeoPoint>> courseGeometry(String id) async => const [];

  /// 픽스처엔 해·달 자료가 없다. 없는 시각을 지어내지 않는다.
  @override
  Future<TodaySky?> todaySky({required double lat, required double lng}) async => null;

  @override
  Future<Map<int, int>> matchRouteKm(List<TripPoint> points) async => const {};

  @override
  Future<Map<int, RouteNote>> routeNotes() async => const {};

  @override
  Future<List<GeoPoint>> routePathAhead({
    required int routeId,
    required double lat,
    required double lng,
    required bool northOrEast,
    double maxKm = 120,
  }) async => const [];

  @override
  Future<List<PlaceHit>> searchPlaces(String query, {double? lat, double? lng}) async => const [];

  @override
  Future<RouteCompare?> compareRoutes({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async => null;

  @override
  Future<NightSky?> nightSkyOn({
    required double lat,
    required double lng,
    required DateTime date,
  }) async => null;

  @override
  Future<List<Spot>> discoverAhead({
    required double lat,
    required double lng,
    double? headingDeg,
    double km = 20,
  }) async => const [];
  @override
  Future<List<Course>> courses({int? routeId}) async => const [];
  @override
  Future<Course?> course(String id) async => null;
  @override
  Future<Spot?> spot(String id) async => null;
  @override
  Future<List<Spot>> search(String q, {bool todayOnly = false, bool nearOnly = false}) async =>
      const [];
  @override
  Future<List<Spot>> nextVisits(String spotId) async => const [];
  @override
  Future<List<CurationCard>> curationDeck() async => const [];
  @override
  Future<List<Discovery>> radarQueue() async => const [];
}

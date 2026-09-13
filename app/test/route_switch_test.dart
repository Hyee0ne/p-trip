import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/drive.dart';
import 'package:p_trip/core/journey.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/trip_log.dart';
import 'package:p_trip/core/widgets/route_badge.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/radar/radar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DR-08 길 바꾸기 (2026-09-13). **여행은 하루, 국도는 구간.**
///
/// 43번을 달리다 6번으로 갈아타도 여행은 하나고, 거리·들른 곳·알린 곳이 이어진다.
/// 전엔 국도 번호가 여행에 고정됐고, 다른 길로 출발하면 주행 거리가 0부터 다시 셌다.
class _WithJourney extends StartedJourney {
  @override
  Journey? build() => const Journey(
    routeId: 7,
    routeName: '동해 바닷길',
    path: [GeoPoint(37.45, 129.17), GeoPoint(37.75, 128.90)],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('구간이 는다 — 제목·뱃지·지금 길이 따라온다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final log = c.read(tripLogProvider.notifier);
    log.start(routeId: 43, routeName: '43번 국도', startName: '', endName: '');
    var t = c.read(tripLogProvider).active!;
    expect(t.segmentsOrSelf.length, 1);
    expect(t.title, '43번 국도에서 생긴 일');

    log.updateDistance(31);
    log.switchRoute(routeId: 6, routeName: '6번 국도', atKm: 31);
    t = c.read(tripLogProvider).active!;
    expect(t.segments.length, 2);
    expect(t.routeIds, [43, 6]);
    expect(t.currentRouteId, 6);
    expect(t.title, '43 → 6번 국도에서 생긴 일');
    expect(t.segments.last.fromKm, 31);

    log.switchRoute(routeId: 6, routeName: '6번 국도', atKm: 40);
    expect(c.read(tripLogProvider).active!.segments.length, 2, reason: '같은 길이면 아무 일도 없다');
  });

  test('옛 기록(구간 없음)은 출발 국도 하나로 읽힌다', () async {
    SharedPreferences.setMockInitialValues({
      'trips.v1':
          '[{"id":"t1","episode":1,"date":"2026.08.27","routeId":7,"routeName":"동해 바닷길",'
          '"startName":"삼척","endName":"강릉","distanceKm":65,"startedAt":"09:00",'
          '"endedAt":"18:00","photoCount":0,"points":[],"stops":[]}]',
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(tripLogProvider);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final t = c.read(tripLogProvider).trips.single;
    expect(t.segments, isEmpty);
    expect(t.segmentsOrSelf.single.routeId, 7);
    expect(t.title, '동해 바닷길에서 생긴 일');
  });

  test('구간은 저장되고 다시 읽힌다', () async {
    final a = ProviderContainer();
    final log = a.read(tripLogProvider.notifier);
    log.start(routeId: 43, routeName: '43번 국도', startName: '', endName: '');
    log.switchRoute(routeId: 6, routeName: '6번 국도', atKm: 12);
    log.end();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    a.dispose();

    final b = ProviderContainer();
    addTearDown(b.dispose);
    b.read(tripLogProvider);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final t = b.read(tripLogProvider).trips.single;
    expect(t.routeIds, [43, 6]);
    expect(t.segments.last.atEpoch, greaterThan(0));
  });

  test('갈아타도 달린 거리는 이어진다 — 새 선형의 첫 점부터 계속', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(driveProvider.notifier);
    n.start(const [GeoPoint(37.45, 129.165), GeoPoint(37.50, 129.140)], kmh: 60, scale: 400);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final ran = c.read(driveProvider).distanceKm;
    expect(ran, greaterThan(0));

    n.switchPath(const [GeoPoint(37.60, 128.90), GeoPoint(37.70, 128.80)]);
    final s = c.read(driveProvider);
    expect(s.distanceKm, ran, reason: '거리는 그대로 — 0부터 다시 세던 구멍');
    expect(s.running, isTrue);
    expect(s.lat, closeTo(37.60, 0.001), reason: '새 선형 첫 점에서 이어 달린다');
    expect(s.frac, 0);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(c.read(driveProvider).distanceKm, greaterThan(ran), reason: '계속 쌓인다');
    n.stop();
  });

  testWidgets('레이더 뱃지 → 「길을 바꿀까요?」 → 고르면 여행은 그대로 구간만 는다', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [startedJourneyProvider.overrideWith(_WithJourney.new)],
        child: const MaterialApp(home: RadarScreen()),
      ),
    );
    Future<void> settle(int frames) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle(8);
    if (find.text(S.cardVisit).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.close).first);
      await settle(3);
    }
    final c = ProviderScope.containerOf(tester.element(find.byType(RadarScreen)));
    final tripId = c.read(tripLogProvider).activeId;
    expect(tripId, isNotNull, reason: '여행이 시작돼 있다');
    final before = c.read(driveProvider).distanceKm;

    await tester.tap(find.byType(RouteBadge).first);
    await settle(6);
    expect(find.text(S.switchTitle), findsOneWidget);
    expect(find.text(S.switchCurrent), findsOneWidget, reason: '7번은 지금 이 길');

    await tester.tap(find.byKey(const ValueKey('switch-38-a')));
    await settle(8);
    final t = c.read(tripLogProvider).active!;
    expect(c.read(tripLogProvider).activeId, tripId, reason: '같은 여행이다');
    expect(t.routeIds, [7, 38]);
    expect(t.currentRouteId, 38);
    expect(c.read(startedJourneyProvider)!.continues, isTrue);
    expect(c.read(driveProvider).running, isTrue);
    expect(c.read(driveProvider).distanceKm, greaterThanOrEqualTo(before), reason: '거리를 되감지 않는다');
    expect(find.text(S.switchedTo(38)), findsOneWidget, reason: '토스트');
    expect(find.text(S.radarFinish), findsWidgets, reason: '여전히 마칠 여행이 있다');
    expect(tester.takeException(), isNull);
  });
}

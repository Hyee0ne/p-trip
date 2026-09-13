import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/geo.dart';
import 'package:p_trip/core/journey.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/trip_log.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/radar/radar_next.dart';
import 'package:p_trip/features/radar/radar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DR-07 「여기서 앞쪽으로」 (2026-09-13). 들른 뒤 다음 후보 — 목적지를 정해 주지 않고 보여만 준다.
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

  group('방향 — 서 있으면 GPS 헤딩 대신 여정 선형', () {
    test('방위: 북 0 · 동 90', () {
      expect(bearingDeg(const GeoPoint(37, 129), const GeoPoint(38, 129)), closeTo(0, 0.5));
      expect(bearingDeg(const GeoPoint(37, 129), const GeoPoint(37, 130)), closeTo(90, 1));
    });
    test('선형에서 가장 가까운 점의 진행 방위 — 끝점이면 마지막 구간', () {
      const path = [GeoPoint(37.0, 129.0), GeoPoint(37.5, 129.0), GeoPoint(37.5, 129.5)];
      expect(routeBearingAt(path, 37.1, 129.0), closeTo(0, 0.5), reason: '첫 구간은 북쪽');
      expect(routeBearingAt(path, 37.5, 129.4), closeTo(90, 1), reason: '끝 근처는 동쪽');
      expect(routeBearingAt(const [GeoPoint(37, 129)], 37, 129), isNull, reason: '점 하나론 방향이 없다');
    });
    test('북·동 판정은 큰 변화 쪽으로', () {
      expect(pathGoesNorthOrEast(const [GeoPoint(37.0, 129.0), GeoPoint(37.5, 128.9)]), isTrue);
      expect(pathGoesNorthOrEast(const [GeoPoint(37.5, 129.0), GeoPoint(37.0, 129.1)]), isFalse);
      expect(pathGoesNorthOrEast(const [GeoPoint(37.0, 129.0), GeoPoint(37.02, 128.0)]), isFalse);
    });
  });

  test('후보 고르기 — 알렸거나 들른 곳은 빼고, 점수 순으로 셋까지', () {
    Discovery d(String id, int score) => Discovery(
      spot: Spot(
        id: id,
        name: id,
        type: SpotType.food,
        routeId: 7,
        detourMin: 3,
        trustScore: score,
      ),
      headline: id,
      lead: '',
      body: '',
    );
    final q = [d('a', 60), d('b', 90), d('c', 70), d('d', 80), d('e', 65)];
    final out = pickNextAhead(q, {'b'}, (s) => s.trustScore.toDouble());
    expect(out.map((x) => x.spot.id), ['d', 'c', 'e'], reason: 'b 는 빠지고, 점수 순, 셋까지');
    expect(pickNextAhead(q, {'a', 'b', 'c', 'd', 'e'}, (s) => 1), isEmpty);
  });

  testWidgets('자취의 「다음」을 누르면 앞쪽 후보가 펼쳐지고, 국도 복귀 링크가 있다', (tester) async {
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
    // 카드가 떠 있으면 넘긴다 — 아래 자취를 눌러야 한다.
    if (find.text(S.cardVisit).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.close).first);
      await settle(3);
    }
    final c = ProviderScope.containerOf(tester.element(find.byType(RadarScreen)));
    c
        .read(tripLogProvider.notifier)
        .addStop(
          const Spot(
            id: 'eaten',
            name: '점심 먹은 집',
            type: SpotType.food,
            routeId: 7,
            detourMin: 3,
            trustScore: 80,
          ),
          StopKind.visited,
        );
    await settle(3);
    expect(find.text(S.nextTitle), findsNothing, reason: '누르기 전엔 접혀 있다');

    await tester.tap(find.text(S.radarStopsNext));
    await settle(6);
    expect(find.text(S.nextTitle), findsOneWidget, reason: '펼쳐진다');
    expect(find.text(S.nextBackToRoute(7)), findsOneWidget, reason: '고르지 않으면 국도로');
    // 픽스처 큐(세 곳) 중 이미 들른 곳은 없으니 후보가 있다. 「들르기」가 행마다.
    expect(find.text(S.cardVisit), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(S.radarStopsNext));
    await settle(3);
    expect(find.text(S.nextTitle), findsNothing, reason: '다시 누르면 접힌다');
  });
}

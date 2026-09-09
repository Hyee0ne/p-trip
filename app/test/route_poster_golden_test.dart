import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/my/route_sketch.dart';

/// MY-02 포스터 (시안 B) — 출발·도착·들른 곳·눈금·거리·뱃지가 한 상자에 (2026-09-09).
/// ⚠ 들른 곳을 10·20·30km 눈금 위에 두면 점이 눈금을 가린다 — 시뮬레이터 확인 때 그래서 안 보였다.
///   여기선 비켜 둔다.
void main() {
  testWidgets('여행기 포스터', (tester) async {
    final t0 = DateTime(2026, 9, 6, 9, 30);
    final pts = [
      for (var i = 0; i < 28; i++)
        TripPoint(
          37.44 + 0.31 * (i / 27) + 0.012 * math.sin(i / 27 * 6.0),
          129.17 - 0.26 * (i / 27) - 0.02 * math.sin(i / 27 * 4.0),
          t0.add(Duration(minutes: i * 9)),
        ),
    ];
    final stops = [
      TripStop(
        spotId: 'a',
        spotName: '북평민속오일장',
        type: SpotType.market,
        at: '10:12',
        kind: StopKind.visited,
        lat: pts[4].lat,
        lng: pts[4].lng - 0.006,
      ),
      TripStop(
        spotId: 'b',
        spotName: '추암 촛대바위',
        type: SpotType.view,
        at: '11:40',
        kind: StopKind.visited,
        lat: pts[11].lat,
        lng: pts[11].lng + 0.006,
      ),
      TripStop(
        spotId: 'c',
        spotName: '어달해변',
        type: SpotType.view,
        at: '13:05',
        kind: StopKind.visited,
        lat: pts[23].lat,
        lng: pts[23].lng + 0.004,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 349,
              child: RouteSketch(
                points: pts,
                height: 240,
                stops: stops,
                distanceKm: 65,
                startName: '삼척',
                endName: '강릉',
                routeId: 7,
                startedAt: '09:30',
                endedAt: '13:42',
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RouteSketch), matchesGoldenFile('goldens/route_poster.png'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/data/models/models.dart';

/// 51선 수집 집계 (맵매칭 결과 ↔ 예전 기록).
///
/// ⚠ 맵매칭 전에 남긴 여행은 `routeKm`이 비어 있다. 0으로 세면 **이미 달린 길이 사라진다**.
void main() {
  Trip trip({required int routeId, required int km, Map<int, int> routeKm = const {}}) => Trip(
    id: 't$routeId-$km',
    episode: 1,
    date: '2026.08.29',
    routeId: routeId,
    routeName: '',
    startName: '',
    endName: '',
    distanceKm: km,
    startedAt: '10:00',
    endedAt: '17:00',
    stops: const [],
    photoCount: 0,
    routeKm: routeKm,
  );

  /// 마이 탭이 쓰는 집계와 같은 규칙.
  Map<int, int> collect(List<Trip> trips) {
    final byRoute = <int, int>{};
    for (final t in trips) {
      if (t.routeKm.isEmpty) {
        byRoute[t.routeId] = (byRoute[t.routeId] ?? 0) + t.distanceKm;
      } else {
        t.routeKm.forEach((r, km) => byRoute[r] = (byRoute[r] ?? 0) + km);
      }
    }
    return byRoute;
  }

  test('한 여행이 여러 국도를 지나면 각자에게 간다', () {
    final got = collect([
      trip(routeId: 7, km: 65, routeKm: {7: 40, 35: 25}),
    ]);
    expect(got, {7: 40, 35: 25});
  });

  test('맵매칭 전 기록은 예전 방식으로 센다', () {
    expect(collect([trip(routeId: 7, km: 65)]), {7: 65});
  });

  test('섞여 있어도 합쳐진다', () {
    final got = collect([
      trip(routeId: 7, km: 65),
      trip(routeId: 7, km: 30, routeKm: {7: 20, 42: 10}),
    ]);
    expect(got, {7: 85, 42: 10});
  });
}

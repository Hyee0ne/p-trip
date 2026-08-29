import 'dart:math' as math;

import '../data/models/models.dart';

/// 대략 거리(km). 위도 37도 부근 평면 근사 — 국내에서 수백 m 판정에는 충분하다.
/// ⚠ 정밀 계산이 필요한 곳(주행 누적 거리)은 haversine을 쓴다 (core/drive.dart).
double roughKm(double aLat, double aLng, double bLat, double bLng) {
  final dx = (bLng - aLng) * 88.0;
  final dy = (bLat - aLat) * 111.0;
  return math.sqrt(dx * dx + dy * dy);
}

/// 경로의 **양 끝을 잘라낸다.** 공유 카드에 집·숙소가 찍히지 않게 하는 장치다
/// (SCREENS.md MY-02 "시작·끝 300m는 가려져요").
///
/// ⚠ 흐리게 하거나 점을 옮기지 않는다. **아예 뺀다** — 가린 척하는 건 안 가린 것이다.
/// ⚠ 자르고 나서 두 점이 안 남으면 빈 목록을 준다. 그 여행은 지도를 그리지 않는다.
List<TripPoint> trimEnds(List<TripPoint> path, {double km = 0.3}) {
  if (path.length < 2) return const [];

  var from = 0;
  while (from < path.length &&
      roughKm(path.first.lat, path.first.lng, path[from].lat, path[from].lng) < km) {
    from++;
  }
  var to = path.length - 1;
  while (to >= 0 && roughKm(path.last.lat, path.last.lng, path[to].lat, path[to].lng) < km) {
    to--;
  }
  if (from > to) return const [];
  final cut = path.sublist(from, to + 1);
  return cut.length < 2 ? const [] : cut;
}

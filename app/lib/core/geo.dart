import 'dart:math' as math;

import '../data/models/models.dart';

/// 대략 거리(km). 위도 37도 부근 평면 근사 — 국내에서 수백 m 판정에는 충분하다.
/// ⚠ 정밀 계산이 필요한 곳(주행 누적 거리)은 haversine을 쓴다 (core/drive.dart).
double roughKm(double aLat, double aLng, double bLat, double bLng) {
  final dx = (bLng - aLng) * 88.0;
  final dy = (bLat - aLat) * 111.0;
  return math.sqrt(dx * dx + dy * dy);
}

/// 두 점 사이 방위(도). 북 0, 동 90, 시계 방향. core/drive.dart 의 계산과 같다.
double bearingDeg(GeoPoint a, GeoPoint b) {
  double rad(double d) => d * math.pi / 180;
  final dLng = rad(b.lng - a.lng);
  final y = math.sin(dLng) * math.cos(rad(b.lat));
  final x =
      math.cos(rad(a.lat)) * math.sin(rad(b.lat)) -
      math.sin(rad(a.lat)) * math.cos(rad(b.lat)) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// 선형 위에서 (lat,lng)에 가장 가까운 점의 **진행 방위**. 서 있을 땐 GPS 헤딩이 흔들려
/// 여정 선형의 방향을 대신 쓴다 (DR-07). 점이 둘 미만이면 null — 방향을 지어내지 않는다.
double? routeBearingAt(List<GeoPoint> path, double lat, double lng) {
  if (path.length < 2) return null;
  var best = 0;
  var bestKm = double.infinity;
  for (var i = 0; i < path.length; i++) {
    final d = roughKm(lat, lng, path[i].lat, path[i].lng);
    if (d < bestKm) {
      bestKm = d;
      best = i;
    }
  }
  final i = best == path.length - 1 ? path.length - 2 : best;
  return bearingDeg(path[i], path[i + 1]);
}

/// 선형이 북·동으로 가는가 — 위도·경도 변화 중 큰 쪽으로 본다. `routePathAhead` 의 northOrEast.
bool pathGoesNorthOrEast(List<GeoPoint> path) {
  if (path.length < 2) return true;
  final dLat = (path.last.lat - path.first.lat) * 111.0;
  final dLng = (path.last.lng - path.first.lng) * 88.0;
  return dLat.abs() >= dLng.abs() ? dLat > 0 : dLng > 0;
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

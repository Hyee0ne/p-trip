import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/geo.dart';
import 'package:p_trip/data/models/models.dart';

/// 공유 카드의 경로 절단 (SCREENS.md MY-02 "시작·끝 300m는 가려져요").
///
/// ⚠ **여기가 개인정보다.** 집·숙소가 남으면 그 문구가 거짓말이 된다.
void main() {
  final t0 = DateTime(2026, 8, 29, 10);

  /// 북쪽으로 [n]개, 100m 간격의 직선 경로.
  List<TripPoint> line(int n) => [
    for (var i = 0; i < n; i++)
      TripPoint(37.4500 + i * 0.0009, 129.1650, t0.add(Duration(minutes: i))),
  ];

  test('양 끝 300m가 사라진다', () {
    final cut = trimEnds(line(20));
    expect(cut.length, lessThan(20));
    // 시작점·끝점이 그대로 남으면 가린 게 아니다.
    expect(cut.first.lat, greaterThan(37.4500));
    expect(cut.last.lat, lessThan(37.4500 + 19 * 0.0009));
    // 잘려나간 앞부분이 실제로 300m 이상이어야 한다.
    expect(roughKm(37.4500, 129.1650, cut.first.lat, cut.first.lng), greaterThanOrEqualTo(0.3));
    expect(
      roughKm(37.4500 + 19 * 0.0009, 129.1650, cut.last.lat, cut.last.lng),
      greaterThanOrEqualTo(0.3),
    );
  });

  test('짧은 여행은 지도를 안 그린다', () {
    // 400m짜리 — 양 끝 300m씩 빼면 남는 게 없다.
    expect(trimEnds(line(5)), isEmpty);
  });

  test('점이 모자라면 빈 목록', () {
    expect(trimEnds(const []), isEmpty);
    expect(trimEnds([TripPoint(37.45, 129.165, t0)]), isEmpty);
  });

  test('제자리에 멈춰 있던 경로는 통째로 사라진다', () {
    // 같은 자리 점만 있으면 시작에서 300m를 못 벗어난다 — 그릴 게 없다.
    final still = [for (var i = 0; i < 10; i++) TripPoint(37.45, 129.165, t0)];
    expect(trimEnds(still), isEmpty);
  });
}

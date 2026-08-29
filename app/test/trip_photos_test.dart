import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/trip_photos.dart';
import 'package:p_trip/data/models/models.dart';

/// 사진을 경로 위에 놓는 규칙 (MY-02).
///
/// ⚠ 여기가 틀리면 **가보지도 않은 곳의 사진**이 여행기에 실린다.
void main() {
  final t0 = DateTime(2026, 8, 29, 10);
  final path = [
    TripPoint(37.4500, 129.1650, t0),
    // 10~30분: 한자리에 멈춰 있었다 (2분 규칙이 남긴 점들)
    TripPoint(37.5000, 129.1400, t0.add(const Duration(minutes: 10))),
    TripPoint(37.5000, 129.1400, t0.add(const Duration(minutes: 30))),
    TripPoint(37.6000, 129.1000, t0.add(const Duration(minutes: 50))),
  ];

  test('멈춰서 찍은 사진은 그 자리에 놓인다', () {
    // 정차 한가운데 찍은 사진
    final p = placeByTime(t0.add(const Duration(minutes: 20)), path);
    expect(p, isNotNull);
    expect(p!.$1, closeTo(37.5, 0.0001), reason: '정차 구간이 경로에 남아 있어야 제자리에 놓인다');
    expect(p.$2, closeTo(129.14, 0.0001));
  });

  test('이동 중 사진은 두 점 사이로 보간된다', () {
    final p = placeByTime(t0.add(const Duration(minutes: 5)), path);
    expect(p!.$1, closeTo(37.475, 0.0001));
  });

  test('여행 전후의 시각은 양 끝으로 붙인다', () {
    expect(placeByTime(t0.subtract(const Duration(hours: 1)), path)!.$1, 37.45);
    expect(placeByTime(t0.add(const Duration(hours: 5)), path)!.$1, 37.60);
  });

  test('경로가 없으면 위치를 지어내지 않는다', () {
    expect(placeByTime(t0, const []), isNull);
  });

  const stops = [
    TripStop(
      spotId: 'a',
      spotName: '묵호등대',
      type: SpotType.attraction,
      at: '10:20',
      kind: StopKind.visited,
      lat: 37.5000,
      lng: 129.1400,
    ),
    TripStop(
      spotId: 'b',
      spotName: '좌표를 모르는 곳',
      type: SpotType.attraction,
      at: '10:40',
      kind: StopKind.visited,
    ),
  ];

  test('300m 안의 들른 곳 이름이 붙는다', () {
    expect(nearestStop(37.5001, 129.1401, stops), '묵호등대');
  });

  test('멀면 아무 이름도 붙이지 않는다', () {
    // 약 5km 떨어진 자리
    expect(nearestStop(37.545, 129.140, stops), isNull);
  });

  test('좌표를 모르는 스팟은 후보가 아니다', () {
    expect(nearestStop(0.0001, 0.0001, stops), isNull, reason: '0,0으로 채웠다면 여기서 걸린다');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/geo.dart';

/// CO-08 출발 시 내비 핸드오프의 목적지 규칙.
///
/// ⚠ **선형의 끝을 목적지로 잡으면 안 된다.** 실측: 7번 북쪽 끝은
///   '고성군 죽왕면 오봉리 산 172-10' — 산속 지번이다. 게다가 120km 앞이라
///   카카오내비가 최단 경로로 안내해서 **고속도로로 빠진다.**
///   국도를 타려고 켠 내비가 국도를 벗어나게 만든다.
/// → 목적지는 **그 국도의 진입점**이다. 짧게 끊어야 그 일이 안 생긴다.
void main() {
  // 데모 위치(동해)에서 7번 국도 선형 첫 점까지 실측 846m.
  const meLat = 37.5245, meLng = 129.1143;
  const entryLat = 37.52675, entryLng = 129.10512;

  test('국도에서 떨어져 있으면 진입점까지 안내가 필요하다', () {
    final km = roughKm(meLat, meLng, entryLat, entryLng);
    expect(km, greaterThan(0.3), reason: '846m — 걸어갈 거리가 아니다');
    expect(km, lessThan(2), reason: '진입점은 가깝다. 멀면 선형이 잘못 잡힌 것');
  });

  test('이미 국도 위면 안내할 게 없다', () {
    // 진입점에서 50m
    final km = roughKm(entryLat, entryLng, entryLat + 0.00045, entryLng);
    expect(km, lessThan(0.3));
  });
}

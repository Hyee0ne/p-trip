import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/drive.dart';

/// 발견 노출 기준 (2026-08-30 개정).
///
/// ⚠ 전에는 '지금 속도로 3~7분 앞'이었다. 속도를 타서 같은 길이라도 막히면 코앞만,
///   뻥 뚫리면 한참 먼 것이 떴다. 이제 **진행 방향 반경 N km**로 잰다.
/// ⚠ 빈도 제한은 없다. 반경 안에 들어온 건 다 알린다 —
///   같은 곳을 두 번 말하지 않게 막는 건 레이더의 `_shown` 뿐이다.
void main() {
  // 100km 코스 위에서 절반쯤 왔다고 두자.
  DriveState at(double frac, {double courseKm = 100}) =>
      DriveState(running: true, frac: frac, courseKm: courseKm);

  test('앞으로 남은 거리를 km로 준다', () {
    expect(at(0.5).kmTo(0.55), closeTo(5, 0.001));
    expect(at(0.5).kmTo(0.52), closeTo(2, 0.001));
  });

  test('이미 지난 곳은 −1 — 뒤를 알리지 않는다', () {
    expect(at(0.5).kmTo(0.45), -1);
    expect(at(0.5).kmTo(0.5), -1, reason: '바로 그 지점도 이미 지난 것으로 본다');
  });

  test('속도가 달라도 거리는 같다 — 이게 시간 기준을 버린 이유다', () {
    final slow = DriveState(running: true, frac: 0.5, courseKm: 100, speedKmh: 20);
    final fast = DriveState(running: true, frac: 0.5, courseKm: 100, speedKmh: 100);
    expect(slow.kmTo(0.56), closeTo(fast.kmTo(0.56), 0.001));
  });

  test('코스가 길수록 같은 비율이 더 먼 거리다', () {
    expect(at(0.5, courseKm: 200).kmTo(0.55), closeTo(10, 0.001));
  });
}

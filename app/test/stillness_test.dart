import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/drive.dart';

/// 정차 판정 (2026-09-13 실기기): 서 있어도 GPS 속도가 1~2m/s 로 튄다. 속도만 보면 정차 2분이 영영 안 찬다.
void main() {
  test('서 있는데 속도가 튀어도 자리를 안 옮겼으면 정차', () {
    expect(DriveNotifier.isStill(1.2, 0.002), isTrue);
    expect(DriveNotifier.isStill(0.0, 0.0), isTrue);
  });
  test('천천히라도 자리를 옮기면 달리는 것', () {
    expect(DriveNotifier.isStill(2.8, 0.003), isFalse, reason: '시속 10km');
    expect(DriveNotifier.isStill(1.0, 0.02), isFalse, reason: '속도는 낮은데 20m 움직였다');
  });
  test('주차장에서 30초 만에 12m 흘러온 건 옮긴 게 아니다 — 픽스는 10m 흔들릴 때만 온다', () {
    expect(DriveNotifier.isStill(1.0, 0.012, sinceSec: 30), isTrue, reason: '0.4m/s');
    expect(DriveNotifier.isStill(1.0, 0.012, sinceSec: 1), isFalse, reason: '12m/s');
    expect(DriveNotifier.isStill(-1, 0.012, sinceSec: 30), isTrue);
  });
  test('속도를 모르면(-1) 자리로만 본다', () {
    expect(DriveNotifier.isStill(-1, 0.001), isTrue);
    expect(DriveNotifier.isStill(-1, 0.01), isFalse);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/drive.dart';
import 'package:p_trip/data/models/models.dart';

/// 앱을 내렸다 돌아왔을 때의 주행.
///
/// ⚠ 실기기에서 발견된 결함이다 — 앱을 한 번 내리면 그 세션 내내 레이더가 죽어 있었다.
///   화면 테스트로는 안 잡힌다. 여기서 잡는다.
void main() {
  // 삼척 → 강릉 방향 대략 선형. 실제 코스 대신 짧게.
  const path = [
    GeoPoint(37.4500, 129.1650),
    GeoPoint(37.5000, 129.1400),
    GeoPoint(37.5500, 129.1200),
    GeoPoint(37.6000, 129.1000),
  ];

  test('앱을 내렸다 돌아와도 달린 거리는 그대로다', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(driveProvider.notifier);

    n.start(path, kmh: 60, scale: 400);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final ran = c.read(driveProvider).distanceKm;
    expect(ran, greaterThan(0), reason: '모의 주행이 실제로 움직여야 한다');

    // 앱을 내림 → 알림을 안 켠 사람은 주행이 멈춘다
    n.stop();
    expect(c.read(driveProvider).running, isFalse);

    // 돌아옴
    n.resume();
    expect(c.read(driveProvider).running, isTrue, reason: '돌아오면 다시 달려야 한다');
    expect(c.read(driveProvider).distanceKm, ran, reason: '달린 만큼은 달린 것이다 — 처음으로 되감으면 안 된다');
    n.stop();
  });

  test('끝난 주행은 resume으로 되살아나지 않는다', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(driveProvider.notifier);

    // 경로가 없으면 달릴 것도 없다.
    n.resume();
    expect(c.read(driveProvider).running, isFalse);
  });
}

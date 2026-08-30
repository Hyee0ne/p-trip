import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/proximity_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DR-06 발신 규칙. **화면 없이 규칙만** 본다 —
/// 여기가 깨지면 뒤에 있는 앱이 하루 종일 말을 걸게 된다.
///
/// ⚠ 2026-08-30 개정: 대상 제한(장날·일몰·기간임박)을 폐기하고 **앞에 있을 때와 같은 발견을**
///   내보낸다. 재촉 금지는 이제 **빈도로만** 지킨다 — 그래서 이 파일이 유일한 방어선이다.
void main() {
  final alerts = ProximityAlerts.instance;
  final t0 = DateTime(2026, 8, 29, 10);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // ⚠ 싱글턴이라 앞 테스트의 횟수를 물고 온다. 매번 지우고 시작한다.
    alerts.debugReset();
  });

  test('처음엔 내보낸다', () async {
    expect(await alerts.allowed(t0), isTrue);
  });

  test('30분에 두 번까지 — 화면 안 쿨다운과 같은 값', () async {
    expect(await alerts.allowed(t0), isTrue);
    await alerts.markSent(t0);

    expect(await alerts.allowed(t0.add(const Duration(minutes: 5))), isTrue, reason: '두 번째는 나간다');
    await alerts.markSent(t0.add(const Duration(minutes: 5)));

    expect(
      await alerts.allowed(t0.add(const Duration(minutes: 10))),
      isFalse,
      reason: '같은 30분 안의 세 번째는 막힌다',
    );
  });

  test('창이 지나가면 다시 열린다', () async {
    await alerts.markSent(t0);
    await alerts.markSent(t0.add(const Duration(minutes: 5)));
    expect(await alerts.allowed(t0.add(const Duration(minutes: 20))), isFalse);
    // 첫 건이 창 밖으로 나가면 한 자리가 난다.
    expect(await alerts.allowed(t0.add(const Duration(minutes: 31))), isTrue);
  });

  test('하루 상한은 없다 — 장거리 주행이 통째로 조용해지면 안 된다', () async {
    var at = t0;
    for (var i = 0; i < 12; i++) {
      expect(await alerts.allowed(at), isTrue, reason: '${i + 1}번째도 나가야 한다');
      await alerts.markSent(at);
      at = at.add(const Duration(minutes: 31));
    }
  });

  test('횟수는 기기에 남는다 — 껐다 켜서 우회할 수 없다', () async {
    await alerts.markSent(t0);
    await alerts.markSent(t0.add(const Duration(minutes: 5)));
    // 앱을 껐다 켠 셈: 메모리만 비우고 저장된 값을 다시 읽게 한다.
    alerts.debugReset();
    expect(
      await alerts.allowed(t0.add(const Duration(minutes: 10))),
      isFalse,
      reason: '저장된 발신 기록을 읽어와야 한다',
    );
  });
}

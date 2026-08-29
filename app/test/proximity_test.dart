import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/proximity_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DR-06 발신 규칙. **화면 없이 규칙만** 본다 —
/// 여기가 깨지면 꺼둔 앱이 하루 종일 말을 걸게 된다.
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

  test('30분 안에는 두 번 안 내보낸다', () async {
    await alerts.markSent(t0);
    expect(await alerts.allowed(t0.add(const Duration(minutes: 29))), isFalse);
    expect(await alerts.allowed(t0.add(const Duration(minutes: 31))), isTrue);
  });

  test('하루 4번이 끝이다', () async {
    var at = t0;
    for (var i = 0; i < 4; i++) {
      expect(await alerts.allowed(at), isTrue, reason: '${i + 1}번째는 나가야 한다');
      await alerts.markSent(at);
      at = at.add(const Duration(minutes: 31));
    }
    expect(await alerts.allowed(at), isFalse, reason: '5번째는 막혀야 한다');
  });

  test('날이 바뀌면 다시 센다', () async {
    var at = t0;
    for (var i = 0; i < 4; i++) {
      await alerts.markSent(at);
      at = at.add(const Duration(minutes: 31));
    }
    expect(await alerts.allowed(at), isFalse);
    expect(await alerts.allowed(t0.add(const Duration(days: 1))), isTrue);
  });
}

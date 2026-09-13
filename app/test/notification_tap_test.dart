import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/proximity_alert.dart';

/// DR-06 알림 탭 → 그 스팟 (2026-09-13).
///
/// 실기기: 티맵을 앞에 두고 달리면 소리는 들리는데 바로 못 누른다. 나중에 알림 센터에서 눌렀을 때
/// 앱만 열리고 끝이었다 — 페이로드(`spot:<id>`)는 있었지만 읽는 코드가 없었다.
void main() {
  test('페이로드에서 스팟 id — 접힘 알림·빈 값은 갈 데가 없다', () {
    expect(ProximityAlerts.spotIdOf('spot:abc-1'), 'abc-1');
    expect(ProximityAlerts.spotIdOf('spot:'), isNull);
    expect(ProximityAlerts.spotIdOf(null), isNull);
    expect(ProximityAlerts.spotIdOf('fold'), isNull);
  });

  test('라우터가 붙기 전에 눌린 알림은 보관했다가 attach 때 연다 — 콜드 스타트', () async {
    final a = ProximityAlerts.instance;
    a.onOpen = null;
    final opened = <String>[];
    a.handleTap('spot:early');
    expect(opened, isEmpty, reason: '아직 갈 라우터가 없다');
    await a.attach(opened.add); // 테스트엔 플러그인이 없다 — 보관분만 처리된다
    expect(opened, ['/spot/early']);
    a.handleTap('spot:later');
    expect(opened, ['/spot/early', '/spot/later'], reason: '붙은 뒤엔 바로 연다');
    a.handleTap('next');
    expect(opened.last, '/radar', reason: '앞쪽 후보 알림은 레이더로');
    a.handleTap(null);
    expect(opened, ['early', 'later'], reason: '접힘 알림은 아무 데도 안 간다');
  });
}

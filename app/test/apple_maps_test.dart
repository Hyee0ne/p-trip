import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/features/handoff/handoff_sheet.dart';

/// App Store 반려 대응 (2026-09-02, Guideline 4 - Design).
///
/// "위치 기능이 내장 지도와 연결되지 않아 사용자를 서드파티 지도 앱에 묶는다."
/// → 애플 지도 선택지를 반드시 둔다. 이 테스트가 그 선택지가 사라지는 걸 막는다.
void main() {
  const spot = HandoffPlace('추암 촛대바위', 37.4520, 129.1720);

  /// ⚠ 거점을 없앴다 (2026-09-07). 전에는 '들르기'에서 목적지 자리에 거점이 들어가고
  ///   누른 스팟이 경유로 갔다. 이제 **누른 곳이 곧 목적지다.**
  ///   경유 자리는 남겨 둔다 — 있으면 그게 먼저라는 규칙은 그대로다.
  group('경유를 못 넘기는 앱은 사용자가 누른 그곳으로 간다', () {
    test('들르기 — 누른 곳이 목적지다', () {
      const sheet = HandoffSheet(mode: HandoffMode.visit, destination: spot);
      expect(sheet.singleTarget.name, spot.name);
      expect(sheet.singleTarget.lat, spot.lat);
    });

    test('경유가 있으면 경유가 먼저다 — 누른 그곳이니까', () {
      const other = HandoffPlace('묵호항', 37.5500, 129.1000);
      const sheet = HandoffSheet(mode: HandoffMode.visit, destination: other, via: [spot]);
      expect(sheet.singleTarget.name, spot.name);
    });

    test('출발에는 경유가 없으니 목적지 그대로', () {
      const sheet = HandoffSheet(mode: HandoffMode.depart, destination: spot);
      expect(sheet.singleTarget.name, spot.name);
    });
  });

  test('좌표가 없으면 넘길 수 없다 — 이름만으로 안내하지 않는다', () {
    const noCoords = HandoffPlace('어딘가', null, null);
    const sheet = HandoffSheet(mode: HandoffMode.visit, destination: noCoords);
    expect(sheet.singleTarget.hasCoords, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/base_camp.dart';
import 'package:p_trip/features/handoff/handoff_sheet.dart';

/// App Store 반려 대응 (2026-09-02, Guideline 4 - Design).
///
/// "위치 기능이 내장 지도와 연결되지 않아 사용자를 서드파티 지도 앱에 묶는다."
/// → 애플 지도 선택지를 반드시 둔다. 이 테스트가 그 선택지가 사라지는 걸 막는다.
void main() {
  const spot = HandoffPlace('추암 촛대바위', 37.4520, 129.1720);
  const camp = BaseCamp(name: '동해 숙소', lat: 37.5245, lng: 129.1143);

  group('경유를 못 넘기는 앱은 사용자가 누른 그곳으로 간다', () {
    test('거점이 있어도 애플 지도·티맵은 스팟으로 — 숙소가 아니다', () {
      final p = HandoffSheet.visitParams(spot: spot, base: camp, driving: true);
      // 카카오는 거점을 목적지로, 스팟을 경유로 받는다 (거점을 지킨다).
      expect(p.destination.name, camp.name);
      expect(p.via.single.name, spot.name);

      final sheet = HandoffSheet(mode: HandoffMode.visit, destination: p.destination, via: p.via);
      // 경유를 못 넘기는 앱은 **누른 그곳**으로 간다.
      expect(sheet.singleTarget.name, spot.name);
      expect(sheet.singleTarget.lat, spot.lat);
    });

    test('거점이 없으면 그냥 스팟이 목적지다', () {
      final p = HandoffSheet.visitParams(spot: spot, base: null, driving: true);
      final sheet = HandoffSheet(mode: HandoffMode.visit, destination: p.destination, via: p.via);
      expect(p.via, isEmpty);
      expect(sheet.singleTarget.name, spot.name);
    });

    test('출발(거점으로 가는 길)에는 경유가 없으니 목적지 그대로', () {
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

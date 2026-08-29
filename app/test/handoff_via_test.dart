import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/base_camp.dart';
import 'package:p_trip/features/handoff/handoff_sheet.dart';

/// 「들르기」가 **오늘 밤 잘 곳을 잃지 않는지**.
///
/// ⚠ 전에는 목적지를 발견으로 바꿔버려서 거점이 사라졌다.
void main() {
  const spot = HandoffPlace('북평 5일장', 37.52, 129.11);
  const base = BaseCamp(name: '묵호항 게스트하우스', lat: 37.55, lng: 129.09);

  test('달리는 중 + 거점 있음 → 거점이 목적지, 발견은 경유지', () {
    final p = HandoffSheet.visitParams(spot: spot, base: base, driving: true);
    expect(p.destination.name, '묵호항 게스트하우스');
    expect(p.via.single.name, '북평 5일장');
  });

  test('거점이 없으면 지킬 목적지가 없다 → 그 곳으로 간다', () {
    final p = HandoffSheet.visitParams(spot: spot, base: null, driving: true);
    expect(p.destination.name, '북평 5일장');
    expect(p.via, isEmpty);
  });

  test('둘러보는 중이면 경유지가 아니다', () {
    final p = HandoffSheet.visitParams(spot: spot, base: base, driving: false);
    expect(p.destination.name, '북평 5일장');
    expect(p.via, isEmpty);
  });

  // BaseCamp.lat/lng는 non-nullable이다 — 좌표 없는 거점은 애초에 만들어지지 않는다.
  // (그 보증은 base_screen에서 '좌표 모르면 거점으로 삼지 않는다'로 지킨다)
}

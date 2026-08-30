import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/data/models/models.dart';

/// CO-06 장소검색이 **거점에 필요한 것만** 들고 오는지.
///
/// ⚠ 거점은 '위치 좌표 입력값'일 뿐이다 (원칙 4). 전화번호·예약 링크를
///   들고 오면 쓰고 싶어진다 — 모델에 자리를 만들지 않는 게 방어다.
void main() {
  test('결과는 이름·주소·좌표뿐이다', () {
    const p = PlaceHit(name: '묵호게스트하우스', addr: '동해시 해안로 513-2', lat: 37.55, lng: 129.11);
    expect(p.name, isNotEmpty);
    expect(p.addr, isNotEmpty);
    expect(p.distanceM, isNull, reason: '위치를 모르면 거리도 없다 — 0으로 채우지 않는다');
  });

  test('거리 표기: 1km 미만은 m', () {
    expect(S.kmAway(0.25), '250m');
    expect(S.kmAway(0.999), '999m');
  });

  test('거리 표기: 1km 이상은 소수 한 자리', () {
    expect(S.kmAway(2.5), '2.5km');
    expect(S.kmAway(12.34), '12.3km');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';

/// 발견 카드 상황 칩의 거리 (2026-09-09).
///
/// 전엔 '국도에서 N분'(detour_min: 노선 최근접점↔스팟 왕복 어림)이라 운전자 입장에선
/// 어디서부터 N분인지 알 수 없었다. 이제 카드가 뜬 순간의 현 위치↔스팟 직선거리를 적는다.
/// ⚠ 분으로 바꾸지 않는다 (원칙 1) · 갱신하지 않는다 (원칙 6) · 모르면 지어내지 않는다.
void main() {
  test('거리 표기 — 1km 아래는 m, 10km 아래는 소수 한 자리, 그 위는 정수', () {
    expect(S.distanceLabel(0.04), '100m');
    expect(S.distanceLabel(0.73), '700m');
    expect(S.distanceLabel(0.96), '1km');
    expect(S.distanceLabel(2.44), '2.4km');
    expect(S.distanceLabel(2.0), '2km');
    expect(S.distanceLabel(12.6), '13km');
  });

  test('앞머리 + 거리 — 거리를 모르면 앞머리만, 없는 숫자를 지어내지 않는다', () {
    expect(S.cardSituation(S.cardNearbyLead, 2.44), '근처에 있어요 · 여기서 약 2.4km');
    expect(S.cardSituation(S.sunsetNote(40), 0.5), '일몰 40분 전 · 여기서 약 500m');
    expect(S.cardSituation(S.cardNearbyLead, null), '근처에 있어요');
  });

  test("'국도에서 N분' 은 카드 문구에서 사라졌다", () {
    expect(S.cardSituation(S.cardNearbyLead, 3), isNot(contains('국도에서')));
    expect(S.cardSituation(S.cardNearbyLead, 3), isNot(contains('분')));
  });
}

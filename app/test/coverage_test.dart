import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/data/repositories/discover_repository.dart';
import 'package:p_trip/data/repositories/fixture_discover_repository.dart';
import 'package:p_trip/data/repositories/providers.dart';

/// 데이터가 없는 지역과 '지금 조용한' 것은 **다른 말을 해야 한다**.
///
/// ⚠ 실기기(2026-09-03): 43번 국도를 달리는데 레이더가 원만 돌고 아무 설명이 없어
///   고장으로 읽혔다. 그 지역은 아직 수집을 안 한 것이지 볼 게 없는 게 아니다.
/// ⚠ 반대로 데이터가 다 찬 7번 국도에서 잠깐 조용할 때 '준비 중'이 뜨면
///   앱이 미완성으로 보인다 — 그건 거짓말이다.
void main() {
  test('데모 구간 안이면 데이터가 있다고 답한다', () async {
    final DiscoverRepository repo = FixtureDiscoverRepository();
    // 삼척 — 데모 구간
    expect(await repo.hasSpotsNear(lat: 37.5245, lng: 129.1143, km: 30), isTrue);
  });

  test('데모 구간 밖이면 없다고 답한다 — 43번 국도(가평) 같은 곳', () async {
    final DiscoverRepository repo = FixtureDiscoverRepository();
    expect(await repo.hasSpotsNear(lat: 37.8297, lng: 127.5148, km: 30), isFalse);
  });

  test('좌표를 0.25도 격자로 뭉갠다 — 주행 중 10m마다 새 조회가 나가면 안 된다', () {
    // 같은 격자 안의 두 지점은 같은 키가 되어야 한다.
    final a = coverageKey(37.5245, 129.1143);
    final b = coverageKey(37.5301, 129.1189); // 약 700m 떨어진 곳
    expect(a, equals(b));

    // 격자를 넘어가면 달라야 한다 — 안 그러면 지역이 바뀌어도 옛 답을 쓴다.
    final far = coverageKey(37.8297, 127.5148);
    expect(a, isNot(equals(far)));
  });

  test('두 문구는 서로 다르고, 준비 중 쪽만 기한을 말하지 않는다', () {
    expect(S.radarNotYet, isNot(equals(S.radarQuiet)));
    expect(S.radarNotYet, contains('준비'));

    // ⚠ 언제 채워질지 모르는데 기한을 암시하면 지키지 못할 약속이다.
    for (final word in ['곧', '며칠', '이번 주', '빠르게']) {
      expect(S.radarNotYet, isNot(contains(word)));
      expect(S.radarNotYetSub, isNot(contains(word)));
    }
  });

  test('조용함 문구는 준비 중이라고 말하지 않는다', () {
    expect(S.radarQuiet, isNot(contains('준비')));
    expect(S.radarQuiet, isNot(contains('아직')));
  });
}

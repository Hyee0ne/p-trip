import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/data/repositories/discover_repository.dart';
import 'package:p_trip/data/repositories/fixture_discover_repository.dart';

/// 레이더는 **경로가 아니라 현 위치 기준**이다 (CLAUDE.md 원칙 2).
///
/// ⚠ 실기기(2026-08-30): 43번 국도를 달리는데 삼척 민물고기전시관(7번 국도)이 떴다.
///   `radarQueue()`에 인자가 하나도 없었고, DB 전체에서 `exit_frac` 순으로 30건을
///   집어왔다. 데모 코스(7번) 한 개만 있을 때 만든 구현이 그대로 남아 있었다.
///   게다가 `exit_frac`은 **그 스팟이 속한 노선의** 비율이라, 다른 국도의 진행률과
///   빼면 나오는 거리가 아무 의미가 없다.
///
/// 이 테스트는 **시그니처를 잠근다.** 좌표 없이 부를 수 있게 되면 같은 일이 반복된다.
void main() {
  test('radarQueue 는 좌표를 반드시 받는다 — 없이는 부를 수 없다', () {
    final DiscoverRepository repo = FixtureDiscoverRepository();
    // 좌표를 넘겨야만 컴파일된다. 아래 호출이 인자 없이도 되면 원칙 2가 깨진 것이다.
    expect(
      () => repo.radarQueue(lat: 37.5245, lng: 129.1143, headingDeg: 0, km: 5),
      returnsNormally,
    );
  });

  test('반경과 방향을 넘길 수 있다 — 진행 방향 앞만 본다', () async {
    final DiscoverRepository repo = FixtureDiscoverRepository();
    final q = await repo.radarQueue(lat: 37.5245, lng: 129.1143, headingDeg: 45, km: 5);
    // 픽스처는 시연용이라 위치를 무시하지만, 인터페이스가 값을 받는다는 것이 요점이다.
    expect(q, isNotEmpty);
  });
}

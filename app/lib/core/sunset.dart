import '../data/models/models.dart';
import 'strings.dart';

/// 일몰 시의성을 발견에 덧입힌다 (SCREENS.md DR-02 · DR-06).
///
/// ⚠ **저장소는 이걸 정할 수 없다.** 일몰 시각은 조회 시점과 위치 격자에 달려 있고,
///   `sun_moon` 캐시는 레이더가 따로 읽는다. 그래서 화면에서 덧입힌다.
///   이게 없으면 실데이터로는 `Timeliness.sunset`이 **한 번도 안 붙고**,
///   DR-06 백그라운드 알림이 통째로 걸러진다 — 규정은 "장날·일몰·기간임박"인데
///   장날과 기간임박만 남는다.
///
/// 창은 §3.1 그대로 **일몰 −60~−20분**. 해 지는 걸 보러 가려면 도착할 시간이 있어야 하고,
/// 20분보다 가까우면 가는 동안 해가 진다.
const int sunsetFromMin = 20;
const int sunsetToMin = 60;

Discovery applySunset(Discovery d, TodaySky? sky, DateTime now) {
  // 장날·기간임박이 이미 붙었으면 건드리지 않는다 — 저장소가 정한 게 우선이다.
  if (d.spot.timeliness != Timeliness.none) return d;
  if (d.spot.type != SpotType.view) return d;

  final left = sky?.minutesToSunset(now);
  if (left == null || left < sunsetFromMin || left > sunsetToMin) return d;

  final s = d.spot.withTimeliness(Timeliness.sunset, S.sunsetNote(left));
  return Discovery(
    spot: s,
    headline: S.sunsetTitle(s.name),
    situation: S.sunsetSituation(left, s.detourMin),
    body: d.body,
  );
}

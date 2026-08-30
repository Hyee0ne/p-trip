import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/sunset.dart';
import 'package:p_trip/data/models/models.dart';

/// 실기기 리포트(2026-08-30): 카카오내비를 켜고 앱을 내려두면 발견 알림이 안 왔다.
///
/// 원인은 백그라운드 처리가 아니라 **시의성**이었다. SCREENS.md DR-06은
/// "장날·일몰·기간임박 중 하나일 때만" 내보내라고 하는데, 실데이터 경로에서
/// `Timeliness.sunset`이 **한 번도 안 붙었다** — 저장소는 일몰 시각을 모른다.
/// 그래서 장날이 아닌 날엔 알림이 구조적으로 0건이었다.
void main() {
  Discovery view(String name, {Timeliness t = Timeliness.none, int detour = 6}) => Discovery(
    spot: Spot(
      id: name,
      name: name,
      type: SpotType.view,
      routeId: 7,
      detourMin: detour,
      trustScore: 90,
      timeliness: t,
    ),
    headline: name,
    situation: '근처에 있어요 · 국도에서 $detour분',
    body: '',
  );

  // 일몰 19:00 인 하늘.
  const sky = TodaySky(sunset: '19:00');
  DateTime at(int h, int m) => DateTime(2026, 8, 30, h, m);

  test('일몰 40분 전 뷰포인트 — 시의성이 붙는다', () {
    final d = applySunset(view('추암 촛대바위'), sky, at(18, 20));
    expect(d.spot.timeliness, Timeliness.sunset);
    expect(d.headline, S.sunsetTitle('추암 촛대바위'));
    expect(d.situation, S.sunsetSituation(40, 6));
  });

  test('창 밖이면 안 붙는다 — 너무 이르거나(−61분) 너무 늦거나(−19분)', () {
    expect(applySunset(view('a'), sky, at(17, 59)).spot.timeliness, Timeliness.none);
    expect(applySunset(view('b'), sky, at(18, 41)).spot.timeliness, Timeliness.none);
    // 경계는 포함한다 (§3.1 −60~−20).
    expect(applySunset(view('c'), sky, at(18, 0)).spot.timeliness, Timeliness.sunset);
    expect(applySunset(view('d'), sky, at(18, 40)).spot.timeliness, Timeliness.sunset);
  });

  test('해가 진 뒤에는 안 붙는다', () {
    expect(applySunset(view('a'), sky, at(19, 30)).spot.timeliness, Timeliness.none);
  });

  test('뷰포인트가 아니면 안 붙는다 — 밥집에 해가 지지는 않는다', () {
    final food = Discovery(
      spot: const Spot(
        id: 'f',
        name: '물회 골목',
        type: SpotType.food,
        routeId: 7,
        detourMin: 4,
        trustScore: 80,
      ),
      headline: '물회 골목',
      situation: '',
      body: '',
    );
    expect(applySunset(food, sky, at(18, 20)).spot.timeliness, Timeliness.none);
  });

  test('장날이 이미 붙었으면 덮어쓰지 않는다 — 저장소가 정한 게 우선', () {
    final d = applySunset(view('장터 전망대', t: Timeliness.marketDay), sky, at(18, 20));
    expect(d.spot.timeliness, Timeliness.marketDay);
  });

  test('하늘을 모르면 안 붙는다 — 없는 일몰을 지어내지 않는다', () {
    expect(applySunset(view('a'), null, at(18, 20)).spot.timeliness, Timeliness.none);
    expect(applySunset(view('b'), const TodaySky(), at(18, 20)).spot.timeliness, Timeliness.none);
  });

  test('withTimeliness 는 나머지 필드를 그대로 옮긴다', () {
    const s = Spot(
      id: 'x',
      name: '묵호등대',
      type: SpotType.view,
      routeId: 7,
      detourMin: 5,
      trustScore: 88,
      blurb: '등대에서 바다가 보인다',
      hasPhoto: true,
      exitFrac: 0.42,
      lat: 37.55,
      lng: 129.11,
    );
    final t = s.withTimeliness(Timeliness.sunset, '일몰 30분 전');
    expect(t.timeliness, Timeliness.sunset);
    expect(t.timelinessNote, '일몰 30분 전');
    for (final pair in [
      [t.id, s.id],
      [t.name, s.name],
      [t.blurb, s.blurb],
      [t.exitFrac, s.exitFrac],
      [t.lat, s.lat],
      [t.lng, s.lng],
      [t.hasPhoto, s.hasPhoto],
      [t.trustScore, s.trustScore],
      [t.detourMin, s.detourMin],
    ]) {
      expect(pair[0], pair[1]);
    }
  });
}

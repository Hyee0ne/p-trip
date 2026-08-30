import '../models/models.dart';

/// 발견 탭이 필요로 하는 읽기 경계.
///
/// 구현은 두 개다:
///  - [FixtureDiscoverRepository] — M1 파이프라인 전까지의 임시. 데모 구간 실존 스팟만.
///  - `SupabaseDiscoverRepository` — M1 이후. 이 인터페이스만 만족하면 화면은 안 고친다.
abstract interface class DiscoverRepository {
  /// 큐레이션 축별 스팟. [axis]가 null이면 전체.
  Future<List<Spot>> spots({CurationAxis? axis, int? routeId});

  /// 국도 51선 메타.
  Future<List<RouteLine>> routes();

  /// 현 위치에서 탈 수 있는 노선 (SCREENS.md CO-07).
  /// 가까운 순. 근처에 없으면 빈 결과 — 억지로 채우지 않는다.
  /// 데이터가 없는 지역은 `covered: false`로 구분해 돌려준다.
  Future<NearbyResult> nearbyRoutes({required double lat, required double lng});

  Future<List<Course>> courses({int? routeId});

  Future<Course?> course(String id);

  /// 코스 선형. 모의 주행이 이 선을 따라간다.
  /// ⚠ 길안내용이 아니다 — "어디를 지나는가"이지 "어떻게 가는가"가 아니다 (원칙 1).
  Future<List<GeoPoint>> courseGeometry(String id);

  Future<Spot?> spot(String id);

  /// 텍스트 검색 (SCREENS.md §SR).
  Future<List<Spot>> search(String query, {bool todayOnly, bool nearOnly});

  /// '들른 차들은 다음에' — 연관 관광지(TECH_SPEC spot_links).
  Future<List<Spot>> nextVisits(String spotId);

  /// 「한 곳씩」 덱 — 스팟·코스·노선이 섞여 흐른다.
  Future<List<CurationCard>> curationDeck();

  /// 오늘 이 자리의 해·달. 일몰 타이밍 가중치(§3.1)와 별 보기 좋은 밤(§3.8)이 쓴다.
  Future<TodaySky?> todaySky({required double lat, required double lng});

  /// 지금 여기서 이 국도를 타고 고른 방향으로 뻗은 선형 (CO-08 길 떠나기).
  /// ⚠ 길안내가 아니다 — 이 길이 이쪽으로 이렇게 뻗어 있다는 사실만 받는다 (원칙 1).
  Future<List<GeoPoint>> routePathAhead({
    required int routeId,
    required double lat,
    required double lng,
    required bool northOrEast,
    double maxKm = 120,
  });

  /// 노선별 한 줄의 근거. 근거 없는 노선은 아예 안 담긴다 (CO-01 재설계).
  Future<Map<int, RouteNote>> routeNotes();

  /// 거점으로 삼을 장소 검색 (CO-06). 위치를 주면 가까운 순으로 정렬만 한다 —
  /// **범위를 막지 않는다.** "어디서 예약했든 상관없어요"가 이 화면의 안내문이다.
  Future<List<PlaceHit>> searchPlaces(String query, {double? lat, double? lng});

  /// 고속도로 ↔ 국도 소요시간 비교 (TECH_SPEC §3.7). **거점 확정 직후 1회.**
  /// ⚠ 길찾기 키는 Edge Function 뒤에 있다. 앱은 분 두 개만 받는다.
  /// ⚠ 비교가 성립하지 않으면(키 없음·경로 없음·국도가 더 빠름) null — 모달을 안 띄운다.
  Future<RouteCompare?> compareRoutes({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  });

  /// 지나온 점들을 노선에 붙여 **노선별 km**를 낸다 (51선 수집).
  /// ⚠ 길안내가 아니다 — 지나온 뒤 어디였는지 셀 뿐이다 (원칙 1).
  Future<Map<int, int>> matchRouteKm(List<TripPoint> points);

  /// 그날 밤의 사실 (MY-02 §3). 데이터가 없으면 null — 없는 밤을 지어내지 않는다.
  Future<NightSky?> nightSkyOn({required double lat, required double lng, required DateTime date});

  /// DR-05 동승자 모드 — 진행 방향 앞쪽을 넓게 훑는다.
  /// ⚠ **신뢰도 게이트를 걸지 않는다.** 얕은 데이터는 알림엔 안 태우되 브라우징엔 보여준다.
  /// ⚠ 경로가 아니라 **현재 위치+방향** 기준이다 (원칙 2).
  Future<List<Spot>> discoverAhead({
    required double lat,
    required double lng,
    double? headingDeg,
    double km = 20,
  });

  /// 레이더 발견 큐 (DR-01/02) — **현 위치 + 진행 방향 반경** 기준.
  ///
  /// ⚠ 2026-08-30 개정. 전에는 인자가 없었고 `exit_frac` 순으로 전 DB에서 30건을 집어왔다.
  ///   데모(7번 국도 한 코스)에서만 맞는 구현이라, 다른 국도를 달리면 **엉뚱한 노선의
  ///   스팟이 떴다** — 43번을 달리는데 삼척(7번) 전시관이 나오는 식이었다.
  ///   원칙 2가 "발견 쿼리는 항상 현 위치+진행 방향 반경"이라고 못박은 이유다.
  /// ⚠ 코스를 벗어나도 그대로 돈다. 경로를 따라가지 않는다.
  Future<List<Discovery>> radarQueue({
    required double lat,
    required double lng,
    double? headingDeg,
    double km,
  });

  // ⚠ 여행기는 여기 없다. **기기 안에** 둔다 (core/trip_log.dart, CLAUDE.md 원칙 5).
  //   로그인을 넣지 않기로 했고, 사진도 기기 안 식별자로만 갖는다.
  //   서버 trips 테이블과 RLS는 남겨뒀다 — 계정이 생기는 날 올려 동기화한다.
}

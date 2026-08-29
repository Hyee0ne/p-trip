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

  /// 레이더 발견 큐 — 데모 모드에서 순서대로 흘러나온다.
  Future<List<Discovery>> radarQueue();

  // ⚠ 여행기는 여기 없다. **기기 안에** 둔다 (core/trip_log.dart, CLAUDE.md 원칙 5).
  //   로그인을 넣지 않기로 했고, 사진도 기기 안 식별자로만 갖는다.
  //   서버 trips 테이블과 RLS는 남겨뒀다 — 계정이 생기는 날 올려 동기화한다.
}

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

  Future<List<Course>> courses({int? routeId});

  Future<Course?> course(String id);

  Future<Spot?> spot(String id);

  /// 텍스트 검색 (SCREENS.md §SR).
  Future<List<Spot>> search(String query, {bool todayOnly, bool nearOnly});

  /// '들른 차들은 다음에' — 연관 관광지(TECH_SPEC spot_links).
  Future<List<Spot>> nextVisits(String spotId);

  /// 「한 곳씩」 덱 — 스팟·코스·노선이 섞여 흐른다.
  Future<List<CurationCard>> curationDeck();

  /// 레이더 발견 큐 — 데모 모드에서 순서대로 흘러나온다.
  Future<List<Discovery>> radarQueue();

  /// 여행기 목록 (최신순).
  Future<List<Trip>> trips();

  Future<Trip?> trip(String id);
}

import '../models/models.dart';
import 'discover_repository.dart';

/// ⚠⚠ 임시 구현 — M1 파이프라인이 붙으면 **이 파일을 통째로 지운다.** ⚠⚠
///
/// CLAUDE.md "목업 데이터로 때우지 말 것" 규칙 때문에 지켜야 할 선:
///  - 여기 있는 스팟은 전부 **CLAUDE.md 데모 기준 데이터의 실존 장소**다. 지어낸 곳이 없다.
///  - 숫자 중 **검증되지 않은 것(trustScore·detourMin)은 파이프라인이 계산할 값의 자리표시**다.
///    실제 값은 TourAPI 응답과 PostGIS 계산에서 나온다.
///  - **이 구현으로 데모하지 않는다.** 시연은 반드시 파이프라인이 적재한 실데이터로 한다.
///  - 변화율(조용히 뜨는 길·차들이 몰래 가는 곳)은 여기서 **만들지 않는다** —
///    두 시점 데이터가 있어야 나오는 값이라 지어내면 거짓말이 된다. 해당 축은 빈 리스트를 준다.
class FixtureDiscoverRepository implements DiscoverRepository {
  const FixtureDiscoverRepository();

  static const _routes = <RouteLine>[
    RouteLine(id: 1, name: '통일을 기다리는 길', axis: 'NS', drivable: false, fromTo: '목포–신의주'),
    RouteLine(id: 7, name: '동해 바닷길', axis: 'NS', drivable: true, fromTo: '부산–고성'),
    RouteLine(id: 24, name: '신안–울산', axis: 'EW', drivable: true, fromTo: '신안–울산'),
    RouteLine(id: 44, name: '한계령길', axis: 'EW', drivable: true, fromTo: '양평–양양'),
    RouteLine(id: 46, name: '경춘길', axis: 'EW', drivable: true, fromTo: '인천–고성'),
    RouteLine(id: 77, name: '해안일주', axis: 'NS', drivable: true, fromTo: '부산–파주'),
  ];

  // CLAUDE.md 데모 기준: 7번 국도 삼척–강릉 구간의 실존 스팟.
  static const _spots = <Spot>[
    Spot(
      id: 'bukpyeong-market',
      name: '북평 5일장',
      type: SpotType.market,
      routeId: 7,
      detourMin: 4,
      trustScore: 88,
      blurb: '3·8일에만 서는 장',
      timeliness: Timeliness.marketDay,
      timelinessNote: '다음 장은 5일 뒤예요',
      openHours: '08:00 – 14:00',
      addr: '강원 동해시 북평동',
      hasPhoto: true,
      parking: '시장 앞 공영주차장',
    ),
    Spot(
      id: 'chuam-chotdae',
      name: '추암 촛대바위',
      type: SpotType.view,
      routeId: 7,
      detourMin: 6,
      trustScore: 91,
      blurb: '바위 사이로 해가 떨어지는 걸 보려고 새벽에도 옵니다',
      timeliness: Timeliness.sunset,
      timelinessNote: '오늘 일몰 19:24',
      addr: '강원 동해시 추암동',
      hasPhoto: true,
    ),
    Spot(
      id: 'eodal-mulhoe',
      name: '어달마을 물회 골목',
      type: SpotType.food,
      routeId: 7,
      detourMin: 4,
      trustScore: 64,
      blurb: '간판 없는 집이 많아요',
      timeliness: Timeliness.mealtime,
      addr: '강원 동해시 어달동',
      hasPhoto: true,
    ),
    Spot(
      id: 'mukho-lighthouse',
      name: '묵호등대',
      type: SpotType.view,
      routeId: 7,
      detourMin: 8,
      trustScore: 82,
      blurb: '논골담길 벽화마을',
      addr: '강원 동해시 묵호진동',
      hasPhoto: true,
    ),
  ];

  static const _courses = <Course>[
    Course(
      id: 'donghae-sea',
      routeId: 7,
      title: '동해 바닷길',
      startName: '삼척',
      endName: '강릉',
      distanceKm: 86,
      durationMin: 130,
      blurb: '삼척에서 강릉까지, 바다만 보고 달리는 길',
      spotIds: ['bukpyeong-market', 'eodal-mulhoe', 'chuam-chotdae', 'mukho-lighthouse'],
    ),
  ];

  @override
  Future<List<RouteLine>> routes() async => _routes;

  @override
  Future<List<Course>> courses({int? routeId}) async =>
      _courses.where((c) => routeId == null || c.routeId == routeId).toList();

  @override
  Future<Course?> course(String id) async => _courses.where((c) => c.id == id).firstOrNull;

  @override
  Future<Spot?> spot(String id) async => _spots.where((s) => s.id == id).firstOrNull;

  @override
  Future<List<Spot>> spots({CurationAxis? axis, int? routeId}) async {
    final byRoute = _spots.where((s) => routeId == null || s.routeId == routeId);
    return switch (axis) {
      CurationAxis.today => byRoute.where((s) => s.timeliness != Timeliness.none).toList(),

      // ⚠ 변화율 축은 두 시점 데이터가 있어야 산출된다. 지어내지 않고 비운다.
      //   SCREENS.md CO-01 상태: "변화율을 못 내는 경우 섹션을 통째로 숨긴다"
      CurationAxis.rising || CurationAxis.tracks => const <Spot>[],

      null => byRoute.toList(),
    };
  }

  @override
  Future<List<Spot>> search(String query, {bool todayOnly = false, bool nearOnly = false}) async {
    final q = query.trim();
    return _spots.where((s) {
      if (q.isNotEmpty && !s.name.contains(q) && !s.blurb.contains(q)) {
        return false;
      }
      if (todayOnly && s.timeliness == Timeliness.none) return false;
      if (nearOnly && s.detourMin > 5) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<Spot>> nextVisits(String spotId) async =>
      _spots.where((s) => s.id != spotId && s.trustScore >= 80).toList();
}

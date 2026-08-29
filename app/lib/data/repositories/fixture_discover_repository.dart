import '../models/models.dart';
import 'discover_repository.dart';

/// ⚠⚠ 임시 구현 — M1 파이프라인이 붙으면 **이 파일을 통째로 지운다.** ⚠⚠
///
/// 2026-08-27 사용자 승인으로 **화면을 채우기 위한 임시값을 넣는다.**
/// (원래 CLAUDE.md는 "목업 데이터로 때우지 말 것"이지만, 파이프라인이 API 키 대기 중이라
///  화면 검토를 먼저 하기로 결정됨.)
///
/// 지켜지는 선:
///  - 장소는 전부 **실존**한다. 7번 국도 삼척–강릉 구간의 실제 지명만 쓴다
///  - 변화율·신뢰도·이탈시간은 **파이프라인이 계산할 값의 자리표시**다. 실값이 아니다
///  - ⚠ **시연·심사 제출은 반드시 파이프라인 실데이터로 한다.** 이 파일로 데모하지 않는다
class FixtureDiscoverRepository implements DiscoverRepository {
  const FixtureDiscoverRepository();

  /// 일반국도 51선 (남북 27 · 동서 24). 홀수=남북, 짝수=동서는 규칙이라 확실하다.
  ///
  /// ⚠ M1 `build-routes.ts`가 표준노드링크로 교체할 임시 시드다.
  ///   - **별명은 우리가 붙인 것**이라 확실한 것만 넣고 나머지는 비운다 → 화면에서 "N번 국도"
  ///   - **기점–종점도 확실한 것만**. 45개를 기억으로 채우면 틀린 정보를 그럴듯하게 넣는 셈이다
  ///   - `drivable=false`(북한 구간으로 완주 불가)는 1번만 확실히 표시. 나머지는 M1에서 판정
  static const _routes = <RouteLine>[
    RouteLine(id: 1, name: '', axis: 'NS', drivable: false, fromTo: '목포–신의주'),
    RouteLine(id: 2, name: '', axis: 'EW', drivable: true, fromTo: '신안–부산'),
    RouteLine(id: 3, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 4, name: '', axis: 'EW', drivable: true, fromTo: '군산–경주'),
    RouteLine(id: 5, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 6, name: '', axis: 'EW', drivable: true, fromTo: '인천–강릉'),
    RouteLine(id: 7, name: '동해 바닷길', axis: 'NS', drivable: true, fromTo: '부산–고성'),
    RouteLine(id: 13, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 14, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 15, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 17, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 18, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 19, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 20, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 21, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 22, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 23, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 24, name: '', axis: 'EW', drivable: true, fromTo: '신안–울산'),
    RouteLine(id: 25, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 26, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 27, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 28, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 29, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 30, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 31, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 32, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 33, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 34, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 35, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 36, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 37, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 38, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 39, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 40, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 42, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 43, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 44, name: '한계령길', axis: 'EW', drivable: true, fromTo: '양평–양양'),
    RouteLine(id: 45, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 46, name: '경춘길', axis: 'EW', drivable: true, fromTo: '인천–고성'),
    RouteLine(id: 47, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 48, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 50, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 58, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 59, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 67, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 75, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 77, name: '해안일주', axis: 'NS', drivable: true, fromTo: '부산–파주'),
    RouteLine(id: 79, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 82, name: '', axis: 'EW', drivable: true, fromTo: ''),
    RouteLine(id: 87, name: '', axis: 'NS', drivable: true, fromTo: ''),
    RouteLine(id: 88, name: '', axis: 'EW', drivable: true, fromTo: ''),
  ];

  // CLAUDE.md 데모 기준: 7번 국도 삼척–강릉 구간의 실존 스팟.
  static const _spots = <Spot>[
    Spot(
      id: 'mangsang-beach',
      name: '망상해수욕장',
      type: SpotType.attraction,
      routeId: 7,
      detourMin: 3,
      trustScore: 79,
      blurb: '모래가 곱고 넓어요',
      addr: '강원 동해시 망상동',
      hasPhoto: true,
    ),
    Spot(
      id: 'mangsang-camp',
      name: '망상 오토캠핑리조트',
      type: SpotType.camp,
      routeId: 7,
      detourMin: 3,
      trustScore: 86,
      blurb: '샤워실 · 화장실 · 전기',
      openHours: '연중무휴',
      addr: '강원 동해시 망상동',
      hasPhoto: true,
    ),
    Spot(
      id: 'mukho-guesthouse',
      name: '묵호항 게스트하우스',
      type: SpotType.stay,
      routeId: 7,
      detourMin: 7,
      trustScore: 72,
      blurb: '묵호등대 도보 7분',
      addr: '강원 동해시 묵호진동',
      hasPhoto: true,
    ),
    Spot(
      id: 'jeongdongjin',
      name: '정동진역',
      type: SpotType.view,
      routeId: 7,
      detourMin: 5,
      trustScore: 90,
      blurb: '바다에서 가장 가까운 기차역',
      addr: '강원 강릉시 강동면',
      hasPhoto: true,
    ),
    Spot(
      id: 'nongol-mural',
      name: '논골담길',
      type: SpotType.culture,
      routeId: 7,
      detourMin: 8,
      trustScore: 74,
      blurb: '언덕을 따라 그려진 벽화 골목',
      addr: '강원 동해시 묵호진동',
      hasPhoto: true,
    ),
    Spot(
      id: 'samcheok-beach',
      name: '삼척해수욕장',
      type: SpotType.attraction,
      routeId: 7,
      detourMin: 4,
      trustScore: 81,
      blurb: '소나무 숲이 해변까지 내려와요',
      addr: '강원 삼척시 갈천동',
      hasPhoto: true,
    ),
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
      id: 'hangyeryeong',
      routeId: 44,
      title: '한계령길',
      startName: '양평',
      endName: '양양',
      distanceKm: 138,
      durationMin: 195,
      blurb: '고개 하나 넘으면 바다가 나오는',
      spotIds: ['jeongdongjin', 'nongol-mural'],
    ),
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

  /// 노선 선형(GeoJSON)이 아직 없어서 거리 계산을 못 한다 (M1 `build-routes.ts`).
  /// 그전까지는 **데모 구간에서 실제로 만나는 국도만** 손으로 적어둔다 —
  /// 7번(동해안 종단) · 38번(동해–제천) · 42번(동해–인천). 전부 실존 노선이다.
  /// 거리는 지어내지 않고 null로 둔다. 구간 밖이면 빈 리스트.
  @override
  Future<NearbyResult> nearbyRoutes({required double lat, required double lng}) async {
    final inDemoArea = lat >= 37.30 && lat <= 37.85 && lng >= 128.85 && lng <= 129.45;
    // 구간 밖은 '국도가 없다'가 아니라 '아직 안 모았다'다. 섞으면 거짓말이 된다.
    if (!inDemoArea) return const NearbyResult.uncovered();
    const ids = [7, 38, 42];
    return NearbyResult([
      for (final id in ids) NearbyRoute(_routes.firstWhere((r) => r.id == id)),
    ], covered: true);
  }

  @override
  Future<List<Course>> courses({int? routeId}) async =>
      _courses.where((c) => routeId == null || c.routeId == routeId).toList();

  @override
  Future<Course?> course(String id) async => _courses.where((c) => c.id == id).firstOrNull;

  /// 픽스처에는 코스 선형이 없다. **좌표를 지어내지 않는다** —
  /// 모의 주행은 실데이터(Supabase)가 붙어 있을 때만 돈다.
  @override
  Future<List<GeoPoint>> courseGeometry(String id) async => const [];

  @override
  Future<Spot?> spot(String id) async => _spots.where((s) => s.id == id).firstOrNull;

  @override
  Future<List<Spot>> spots({CurationAxis? axis, int? routeId}) async {
    final byRoute = _spots.where((s) => routeId == null || s.routeId == routeId);
    return switch (axis) {
      CurationAxis.today => byRoute.where((s) => s.timeliness != Timeliness.none).toList(),

      // ⚠ 임시값. 실제로는 데이터랩·연관관광지의 두 시점 비교에서 나온다.
      CurationAxis.rising =>
        byRoute.where((s) => const {'jeongdongjin', 'samcheok-beach'}.contains(s.id)).toList(),
      CurationAxis.tracks =>
        byRoute.where((s) => const {'nongol-mural', 'mangsang-beach'}.contains(s.id)).toList(),

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

  // ── 「한 곳씩」 덱 ──
  //
  // 큐레이션 3축이 카드 종류가 된다: 오늘만(스팟) · 조용히 뜨는 길(코스) · 아직 안 달린 길(노선).
  // 한 종류만 연달아 나오지 않게 섞어서 낸다.
  @override
  Future<List<CurationCard>> curationDeck() async {
    Spot byId(String id) => _spots.firstWhere((s) => s.id == id);
    return [
      SpotCurationCard(
        spot: byId('bukpyeong-market'),
        kicker: '오늘만 · 다음 장은 5일 뒤',
        kickerColor: CardAccent.today,
        body: '3·8일에만 서요. 메밀전 부치는 냄새가 골목까지 납니다.',
        meta: '동해 바닷길 · 국도에서 4분',
        route: '/course/donghae-sea',
      ),
      CourseCurationCard(
        course: _courses.firstWhere((c) => c.id == 'donghae-sea'),
        coverKey: 'samcheok-beach',
        kicker: '지난주보다 검색 +38%',
        body: '삼척에서 강릉까지, 바다만 보고 달리는 길.\n오늘 이 길에 장이 섭니다.',
        meta: '86km · 발견 9곳 · 순수 주행 2:10',
      ),
      SpotCurationCard(
        spot: byId('chuam-chotdae'),
        kicker: '오늘 일몰 19:24',
        kickerColor: CardAccent.today,
        body: '바위 사이로 해가 떨어지는 걸 보려고 새벽에도 옵니다.',
        meta: '동해 바닷길 · 국도에서 6분',
        route: '/course/donghae-sea',
      ),
      SpotCurationCard(
        spot: byId('nongol-mural'),
        kicker: '차량 유입이 늘고 있어요',
        kickerColor: CardAccent.tracks,
        body: '언덕을 따라 그려진 벽화 골목. 들른 차들은 다음에 묵호등대로 갔어요.',
        meta: '동해 바닷길 · 국도에서 8분',
        route: '/course/donghae-sea',
      ),
      RouteCurationCard(
        line: _routes.firstWhere((r) => r.id == 44),
        coverKey: 'jeongdongjin',
        kicker: '아직 안 달린 길',
        body: '고개 하나 넘으면 바다가 나옵니다.\n51선 중 3선째 — 이 길이 네 번째가 됩니다.',
        meta: '양평–양양 · 138km',
      ),
    ];
  }

  // ── 레이더 발견 큐 (DR-02) ──
  @override
  Future<List<Discovery>> radarQueue() async => const [
    Discovery(
      spot: Spot(
        id: 'bukpyeong-market',
        name: '북평 5일장',
        type: SpotType.market,
        routeId: 7,
        detourMin: 4,
        trustScore: 88,
        timeliness: Timeliness.marketDay,
        timelinessNote: '다음 장은 5일 뒤예요',
        hasPhoto: true,
      ),
      headline: '오늘이 마침\n북평 5일장이에요',
      situation: '동해IC 진출로 4분 전 · 오늘만',
      body: '3·8일에만 서는 장이라, 다음 장은 5일 뒤예요.',
    ),
    Discovery(
      spot: Spot(
        id: 'eodal-mulhoe',
        name: '어달마을 물회 골목',
        type: SpotType.food,
        routeId: 7,
        detourMin: 4,
        trustScore: 64,
        timeliness: Timeliness.mealtime,
        hasPhoto: true,
      ),
      headline: '어달마을에\n물회 골목이 있어요',
      situation: '근처에 있어요 · 국도에서 4분',
      body: '간판 없는 집이 많아요. 들른 차들은 다음에 묵호등대로 갔어요.',
    ),
    Discovery(
      spot: Spot(
        id: 'chuam-chotdae',
        name: '추암 촛대바위',
        type: SpotType.view,
        routeId: 7,
        detourMin: 6,
        trustScore: 91,
        timeliness: Timeliness.sunset,
        timelinessNote: '오늘 일몰 19:24',
        hasPhoto: true,
      ),
      headline: '곧 추암 촛대바위에\n해가 져요',
      situation: '일몰 40분 전 · 국도에서 6분',
      body: '바위 사이로 해가 떨어지는 걸 보려고 새벽에도 옵니다.',
    ),
  ];

  // ── 여행기 (MY-02) ──
  static const _trips = <Trip>[
    Trip(
      id: 'ep3',
      episode: 3,
      date: '2026.08.27',
      routeId: 7,
      routeName: '7번 국도',
      startName: '삼척',
      endName: '강릉',
      distanceKm: 86,
      startedAt: '06:40',
      endedAt: '20:50',
      photoCount: 11,
      stops: [
        TripStop(
          spotId: 'bukpyeong-market',
          spotName: '북평 5일장',
          type: SpotType.market,
          at: '08:12',
          kind: StopKind.visited,
          note: '"오늘이 마침 장날" 알림에 핸들을 꺾음',
          stayMin: 68,
        ),
        TripStop(
          spotId: 'eodal-mulhoe',
          spotName: '어달마을 물회 골목',
          type: SpotType.food,
          at: '13:20',
          kind: StopKind.skunked,
          note: '문이 닫혀 있었음. 그래도 골목은 예뻤음',
          stayMin: 9,
        ),
        TripStop(
          spotId: 'mangsang-beach',
          spotName: '망상해수욕장',
          type: SpotType.attraction,
          at: '15:40',
          kind: StopKind.passed,
          note: '수다 떨다 지나침',
        ),
        TripStop(
          spotId: 'nongol-mural',
          spotName: '논골담길',
          type: SpotType.culture,
          at: '17:02',
          kind: StopKind.passed,
          note: '다음에',
        ),
        TripStop(
          spotId: 'mukho-lighthouse',
          spotName: '묵호등대',
          type: SpotType.view,
          at: '18:05',
          kind: StopKind.passed,
          note: '해 지기 전에 촛대바위로',
        ),
        TripStop(
          spotId: 'chuam-chotdae',
          spotName: '추암 촛대바위',
          type: SpotType.view,
          at: '19:11',
          kind: StopKind.visited,
          note: '일몰 13분 전 도착. 빛이 제일 좋을 때',
          stayMin: 41,
        ),
      ],
    ),
    Trip(
      id: 'ep2',
      episode: 2,
      date: '2026.08.14',
      routeId: 44,
      routeName: '44번 국도',
      startName: '양평',
      endName: '양양',
      distanceKm: 138,
      startedAt: '07:10',
      endedAt: '19:30',
      photoCount: 24,
      stops: [
        TripStop(
          spotId: 'jeongdongjin',
          spotName: '정동진역',
          type: SpotType.view,
          at: '09:30',
          kind: StopKind.visited,
          note: '기차가 바다 옆으로 지나감',
          stayMin: 35,
        ),
        TripStop(
          spotId: 'nongol-mural',
          spotName: '논골담길',
          type: SpotType.culture,
          at: '14:20',
          kind: StopKind.visited,
          note: '언덕 끝까지 걸어 올라감',
          stayMin: 52,
        ),
        TripStop(
          spotId: 'samcheok-beach',
          spotName: '삼척해수욕장',
          type: SpotType.attraction,
          at: '17:00',
          kind: StopKind.passed,
          note: '비가 와서 지나침',
        ),
      ],
    ),
  ];

  @override
  Future<List<Trip>> trips() async => _trips;

  @override
  Future<Trip?> trip(String id) async => _trips.where((t) => t.id == id).firstOrNull;
}

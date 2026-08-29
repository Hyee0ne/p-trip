/// 도메인 모델 — TECH_SPEC.md §2 스키마와 1:1로 맞춘다.
///
/// ⚠ 별점·후기·랭킹 필드를 만들지 않는다 (CLAUDE.md 원칙 3).
///   신뢰는 [Spot.trustScore]와 [SpotLink](이동 흔적)로만 표현한다.
library;

/// 스팟 유형. 관광지·음식점·문화시설·뷰포인트·숙박·캠핑장·시장이 **전부 동급**이다.
enum SpotType { market, food, view, culture, stay, camp, attraction }

/// 오늘 이 스팟이 갖는 시의성. 발견 점수의 타이밍 가중치(TECH_SPEC §3.1)와 대응.
enum Timeliness {
  /// 오늘 장날. 가중치 ×3.
  marketDay,

  /// 일몰 −60~−20분 뷰포인트. ×2.
  sunset,

  /// 11–14시 음식점. ×2.
  mealtime,

  /// 기간 임박 행사.
  endingSoon,

  none,
}

/// 지도에 찍는 좌표 한 점.
///
/// ⚠ 카카오 `LatLng`을 쓰지 않는다 — 데이터 계층이 지도 플러그인에 묶이면
/// M0.5에서 플러그인을 갈아탈 때 모델까지 따라 바뀐다.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

class RouteLine {
  const RouteLine({
    required this.id,
    required this.name,
    required this.axis,
    required this.drivable,
    required this.fromTo,
    this.paths = const [],
  });

  /// 노선 번호. 7, 44, 46…
  final int id;

  /// 별명. '동해 바닷길'
  final String name;

  /// 'NS'(홀수·남북) | 'EW'(짝수·동서)
  final String axis;

  /// 북한 구간이면 false. UI에서 회색 뱃지 + '통일을 기다리는 길'
  final bool drivable;

  /// '부산–고성'
  final String fromTo;

  /// 지도용 노선 선형. **갈래가 여럿이다** — 국도는 도심통과·우회로 실제로 끊겨 있고
  /// DB도 MultiLineString으로 담는다. 한 갈래로 억지로 이으면 노선 대부분을 버리게 된다.
  /// 비어 있으면 지도에 그리지 않는다 — 없는 선을 그리지 않는다.
  final List<List<GeoPoint>> paths;
}

/// 현 위치 조회 결과.
///
/// 빈 목록에는 뜻이 둘이다 — "여기엔 국도가 없다"와 "이 지역 데이터를 아직 안 모았다".
/// 둘을 섞으면 데이터가 없는 지역에서 "국도가 없다"고 거짓말을 하게 된다.
class NearbyResult {
  const NearbyResult(this.routes, {required this.covered});

  const NearbyResult.uncovered() : routes = const [], covered = false;

  final List<NearbyRoute> routes;

  /// 이 좌표 주변 노선 데이터를 가지고 있는가.
  /// 파이프라인이 전국을 채우면(M1) 항상 true가 된다.
  final bool covered;

  bool get isEmpty => routes.isEmpty;
}

/// 현 위치에서 탈 수 있는 노선 하나.
class NearbyRoute {
  const NearbyRoute(this.route, {this.distanceKm});

  final RouteLine route;

  /// 현 위치에서 노선까지 최단 거리. **모르면 null** — 지어내지 않는다.
  /// 노선 선형이 들어오는 M1부터 실제 값이 찬다.
  final double? distanceKm;
}

class Spot {
  const Spot({
    required this.id,
    required this.name,
    required this.type,
    required this.routeId,
    required this.detourMin,
    required this.trustScore,
    this.blurb = '',
    this.timeliness = Timeliness.none,
    this.timelinessNote = '',
    this.openHours,
    this.tel,
    this.addr,
    this.hasPhoto = false,
    this.parking,
    this.imageUrl,
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final SpotType type;
  final int routeId;

  /// 국도 진출점에서 스팟까지 왕복 추정(분). ⚠ 실측 소요시간이 아니다 (TECH_SPEC §2).
  final int detourMin;

  /// 0~100. 사진·영업정보 완성도. 60 이상만 레이더 카드 후보 (신뢰도 게이트).
  final int trustScore;

  /// 한 줄 소개.
  final String blurb;

  final Timeliness timeliness;

  /// '다음 장은 5일 뒤' / '오늘 일몰 19:24' 처럼 시의성에 붙는 문구.
  final String timelinessNote;

  final String? openHours;
  final String? tel;
  final String? addr;
  final bool hasPhoto;
  final String? parking;

  /// TourAPI 대표사진 URL. 없으면 유형 그라데이션이 자리를 지킨다.
  final String? imageUrl;

  /// 좌표. **없으면 길안내로 넘길 수 없다** — 내비 앱은 이름만으로 못 간다.
  final double? lat;
  final double? lng;

  /// 레이더 카드·푸시에 태울 수 있는가 (TECH_SPEC §3.1 3번).
  bool get passesTrustGate => trustScore >= 60;
}

class Course {
  const Course({
    required this.id,
    required this.routeId,
    required this.title,
    required this.startName,
    required this.endName,
    required this.distanceKm,
    required this.durationMin,
    required this.blurb,
    required this.spotIds,
  });

  final String id;
  final int routeId;
  final String title;
  final String startName;
  final String endName;
  final int distanceKm;

  /// 순수 주행시간(분). ⚠ 도착 시각으로 환산해 표기하지 않는다 (비내비 원칙).
  final int durationMin;
  final String blurb;
  final List<String> spotIds;

  /// '2:10'
  String get durationLabel =>
      '${durationMin ~/ 60}:${(durationMin % 60).toString().padLeft(2, '0')}';
}

/// 큐레이션 3축 (SCREENS.md CO-01).
enum CurationAxis {
  /// 오늘만 열리는 발견 — 장날·일몰·기간 임박.
  today,

  /// 조용히 뜨는 길 — 데이터랩 검색·방문 변화율.
  rising,

  /// 요즘 차들이 몰래 가는 곳 — 연관 관광지 유입 변화율.
  tracks,
}

/// 여행 기록 (TECH_SPEC §2 trips).
enum TripStatus { draft, active, ended }

/// 정차 종류. skunked = 허탕 — 실패도 기록한다 (기획문서 §5-⑴ 실패의 서사화).
enum StopKind { visited, passed, skunked }

class TripStop {
  const TripStop({
    required this.spotId,
    required this.spotName,
    required this.type,
    required this.at,
    required this.kind,
    this.note = '',
    this.stayMin,
  });

  final String spotId;
  final String spotName;
  final SpotType type;

  /// 'HH:mm'
  final String at;
  final StopKind kind;

  /// 자동 생성 한 줄. "'오늘이 마침 장날' 알림에 핸들을 꺾음"
  final String note;
  final int? stayMin;
}

class Trip {
  const Trip({
    required this.id,
    required this.episode,
    required this.date,
    required this.routeId,
    required this.routeName,
    required this.startName,
    required this.endName,
    required this.distanceKm,
    required this.startedAt,
    required this.endedAt,
    required this.stops,
    required this.photoCount,
  });

  final String id;
  final int episode;

  /// '2026.08.27'
  final String date;
  final int routeId;
  final String routeName;
  final String startName;
  final String endName;
  final int distanceKm;
  final String startedAt;
  final String endedAt;
  final List<TripStop> stops;
  final int photoCount;

  int get visited => stops.where((s) => s.kind == StopKind.visited).length;
  int get passed => stops.where((s) => s.kind == StopKind.passed).length;
  int get skunked => stops.where((s) => s.kind == StopKind.skunked).length;

  /// '7번 국도에서 생긴 일'
  String get title => '$routeName에서 생긴 일';
}

/// DR-02 근접 발견 카드에 실을 한 건.
class Discovery {
  const Discovery({
    required this.spot,
    required this.headline,
    required this.situation,
    required this.body,
  });

  final Spot spot;

  /// 존재형 문구. "오늘이 마침 북평 5일장이에요"
  final String headline;

  /// 상황 라벨. "동해IC 진출로 4분 전 · 오늘만"
  final String situation;
  final String body;
}

/// 「한 곳씩」 덱에 흐르는 카드 (SCREENS.md CO-01 A).
///
/// ⚠ 스팟만 흐르지 않는다. 큐레이션 3축이 그대로 카드 종류가 된다 —
///   오늘만(스팟) · 조용히 뜨는 길(코스) · 아직 안 달린 길(노선).
sealed class CurationCard {
  const CurationCard({
    required this.kicker,
    required this.kickerColor,
    required this.title,
    required this.body,
    required this.meta,
    required this.ctaLabel,
    required this.route,
    required this.imageKey,
    required this.type,
  });

  /// 카드 상단 흰 알약 문구. "오늘만 · 다음 장은 5일 뒤"
  final String kicker;

  /// 알약 앞 점 색 — 시의성을 색으로 먼저 알린다.
  final CardAccent kickerColor;

  final String title;
  final String body;

  /// RouteBadge 옆 한 줄. "동해 바닷길 · 국도에서 4분"
  final String meta;

  /// 주 버튼 문구. "이 길 보기" / "이 코스 보기"
  final String ctaLabel;

  /// 주 버튼이 가는 곳.
  final String route;

  /// `assets/images/<imageKey>.jpg`
  final String imageKey;

  /// 사진이 없을 때 쓸 유형색.
  final SpotType type;

  /// 원격 사진 URL. 없으면 [imageKey] 에셋을, 그것도 없으면 유형 그라데이션을 쓴다.
  String? get imageUrl => null;

  /// 카드 전체를 탭했을 때 가는 곳 (자세히).
  String get detailRoute;

  /// 노선 뱃지에 쓸 번호.
  int get routeId;
}

enum CardAccent { today, rising, tracks, route }

class SpotCurationCard extends CurationCard {
  const SpotCurationCard({
    required this.spot,
    required super.kicker,
    required super.kickerColor,
    required super.body,
    required super.meta,
    required super.route,
  }) : super(title: '', ctaLabel: '이 길 보기', imageKey: '', type: SpotType.attraction);

  final Spot spot;

  @override
  String get title => spot.name;
  @override
  String get imageKey => spot.id;
  @override
  String? get imageUrl => spot.imageUrl;
  @override
  SpotType get type => spot.type;
  @override
  int get routeId => spot.routeId;
  @override
  String get detailRoute => '/spot/${spot.id}';
}

class CourseCurationCard extends CurationCard {
  const CourseCurationCard({
    required this.course,
    required this.coverKey,
    this.coverUrl,
    required super.kicker,
    required super.body,
    required super.meta,
  }) : super(
         kickerColor: CardAccent.rising,
         title: '',
         ctaLabel: '이 코스 보기',
         route: '',
         imageKey: '',
         type: SpotType.attraction,
       );

  final Course course;

  /// 표지로 쓸 스팟 사진 키.
  final String coverKey;

  /// 표지 원격 사진. 코스 위 첫 스팟의 사진을 쓴다.
  final String? coverUrl;

  @override
  String? get imageUrl => coverUrl;

  @override
  String get title => course.title;
  @override
  String get imageKey => coverKey;
  @override
  int get routeId => course.routeId;
  @override
  String get route => '/course/${course.id}';
  @override
  String get detailRoute => '/course/${course.id}';
}

class RouteCurationCard extends CurationCard {
  const RouteCurationCard({
    required this.line,
    required this.coverKey,
    required super.kicker,
    required super.body,
    required super.meta,
  }) : super(
         kickerColor: CardAccent.route,
         title: '',
         ctaLabel: '이 길 보기',
         route: '/routes',
         imageKey: '',
         type: SpotType.view,
       );

  final RouteLine line;
  final String coverKey;

  @override
  String get title => '${line.id}번 국도\n${line.name}';
  @override
  String get imageKey => coverKey;
  @override
  int get routeId => line.id;
  @override
  String get detailRoute => '/routes';
}

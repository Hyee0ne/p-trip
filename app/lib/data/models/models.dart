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
    this.totalKm = 0,
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

  /// 총 연장(km). 0이면 아직 선형을 안 넣은 노선이다.
  final int totalKm;

  /// 지도용 노선 선형. **갈래가 여럿이다** — 국도는 도심통과·우회로 실제로 끊겨 있고
  /// DB도 MultiLineString으로 담는다. 한 갈래로 억지로 이으면 노선 대부분을 버리게 된다.
  /// 비어 있으면 지도에 그리지 않는다 — 없는 선을 그리지 않는다.
  final List<List<GeoPoint>> paths;
}

class TodaySky {
  const TodaySky({this.sunset});

  /// 'HH:mm'
  ///
  /// ⚠ 월출·월몰·천문박명도 같은 응답에 오지만 **모델에 담지 않는다** (2026-09-07).
  ///   '별 보기 좋은 밤'(§3.8)을 지우면서 읽는 곳이 없어졌다.
  ///   파이프라인은 계속 받아 둔다 — 나중에 그 기능을 붙이면 그때 여기 꺼내 쓴다.
  final String? sunset;

  /// 일몰까지 남은 분. 모르면 null, 이미 졌으면 음수.
  int? minutesToSunset(DateTime now) {
    final t = _parse(sunset, now);
    if (t == null) return null;
    return t.difference(DateTime(now.year, now.month, now.day, now.hour, now.minute)).inMinutes;
  }

  /// 'HH:mm' 을 [on] **그 날의** 시각으로 읽는다.
  ///
  /// ⚠ 전에는 여기서 `DateTime.now()`로 날짜를 만들었다. 호출부는 인자로 받은 날짜와
  ///   빼는데 날이 다르면 결과가 며칠치 분으로 튄다. 운영에선 둘 다 오늘이라 안 드러났고,
  ///   날짜를 고정한 테스트가 **날이 바뀐 뒤에** 깨지면서 드러났다 (2026-09-03).
  DateTime? _parse(String? hhmm, DateTime on) {
    if (hhmm == null || hhmm.length < 5) return null;
    final h = int.tryParse(hhmm.substring(0, 2));
    final m = int.tryParse(hhmm.substring(3, 5));
    if (h == null || m == null) return null;
    return DateTime(on.year, on.month, on.day, h, m);
  }
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
/// 노선에 붙는 한 줄의 근거 (CO-01 재설계).
///
/// 노선 한 줄의 근거. 근거가 없는 노선에는 아예 줄이 없다.
///
/// - [marketToday] 오늘 그 길에 장이 선다
/// - [rising] 두 시점 사이에 **순위가 오른** 곳이 있다 — 관찰한 변화다
/// - [popular] 변화는 못 쟀지만 **이동 흔적**이 많다 (2026-09-04 추가)
///
/// ⚠ [popular] 도 별점·후기가 아니다. 연관관광지는 '여기 간 사람이 저기도 갔다'는
///   흔적이다 (원칙 3 — 별점·후기는 여전히 없다).
/// ⚠ [rising] 과 [popular] 를 한 문구로 말하지 않는다. 절대 순위로 뽑힌 길은
///   '요즘 더' 도는 게 아니다 — 그렇게 쓰면 거짓말이 된다.
enum RouteNoteKind { marketToday, rising, popular }

class RouteNote {
  const RouteNote(this.kind, this.spots);

  final RouteNoteKind kind;

  /// 그 근거에 해당하는 스팟 수. **개수는 안심의 근거지 계획표가 아니다** —
  /// 목록은 보여주지 않는다.
  final int spots;
}

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
    this.exitFrac,
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

  /// 코스 선형 위 위치비 0~1. 진행률과 비교해 **앞에 있는 발견**을 고른다 (§3.1).
  final double? exitFrac;

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
///
/// ⚠ **`passed`(스쳐간 곳)는 없앴다** (2026-09-07). 옛 기록에 남아 있을 수 있어
///   `trip_log`가 불러올 때 버린다 — `visited`로 흘러가면 안 가본 곳이 들른 곳이 된다.
enum StopKind { visited, skunked }

class TripStop {
  const TripStop({
    required this.spotId,
    required this.spotName,
    required this.type,
    required this.at,
    required this.kind,
    this.lat,
    this.lng,
    this.note = '',
    this.imageUrl,
  });

  final String spotId;
  final String spotName;
  final SpotType type;

  /// 그 스팟의 대표 사진. 레이더 「오늘 들른 곳」 자취와 여행기 행이 쓴다 (2026-09-09).
  /// ⚠ 없으면 유형색 원. 이전 기록엔 없다 — 지어내지 않는다.
  final String? imageUrl;

  /// 'HH:mm'
  final String at;
  final StopKind kind;

  /// 그 스팟의 좌표. 사진을 어느 곳에서 찍었는지 귀속할 때 쓴다 (MY-02).
  /// ⚠ null이면 '모른다'는 뜻이다. 0,0으로 채우지 않는다 — 기니만으로 안내하게 된다.
  final double? lat;
  final double? lng;

  /// 자동 생성 한 줄. "'오늘이 마침 장날' 알림에 핸들을 꺾음"
  ///
  /// ⚠ 체류 시간(`stayMin`)이 있었다 → **폐기 (2026-09-07).** 채우는 코드가 없어
  ///   실제로는 언제나 null 이었다 — 화면에 한 번도 안 뜬 칸이다.
  final String note;
}

/// 주행 중 찍은 점 하나. **시각이 좌표만큼 중요하다** —
/// 사진을 경로에 꽂을 때(MY-02) 기준이 되는 게 촬영 시각이다.
class TripPoint {
  const TripPoint(this.lat, this.lng, this.at);

  final double lat;
  final double lng;
  final DateTime at;
}

/// 여행 안의 국도 구간 (DR-08, 2026-09-13). **여행은 하루, 국도는 구간이다.**
/// 43번을 달리다 6번으로 갈아타도 여행은 하나고, 구간이 하나 늘 뿐이다.
class TripSegment {
  const TripSegment({
    required this.routeId,
    required this.routeName,
    required this.fromKm,
    required this.at,
    required this.atEpoch,
  });

  final int routeId;
  final String routeName;

  /// 이 구간이 시작된 누적 주행거리(km). 첫 구간은 0.
  final double fromKm;

  /// 'HH:mm' — 타임라인용.
  final String at;

  /// 초 단위 epoch — 포스터가 경로를 구간 색으로 나누는 기준. 옛 기록은 0.
  final int atEpoch;
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
    this.courseId = '',
    this.routeKm = const {},
    this.coverPhotoId = '',
    this.coverPath = '',
    this.segments = const [],
  });

  final String id;
  final int episode;

  /// '2026.08.27'
  final String date;
  final int routeId;

  /// 이 여행이 출발할 때 고른 코스. 비어 있으면 '코스 없이 그냥 달렸다'는 뜻이다.
  /// ⚠ "계획에 없던 밥"을 세려면 **무엇이 계획이었는지**를 알아야 한다 (MY-02).
  final String courseId;

  /// 맵매칭 결과 — 노선번호별로 실제 달린 km.
  ///
  /// ⚠ 비어 있으면 **아직 안 재본 여행**이다 (맵매칭 전에 기록된 것). 그때는
  ///   `routeId`에 `distanceKm`를 통째로 얹는 예전 방식으로 센다 — 0으로 지우지 않는다.
  final Map<int, int> routeKm;
  final String routeName;
  final String startName;
  final String endName;
  final int distanceKm;
  final String startedAt;
  final String endedAt;
  final List<TripStop> stops;
  final int photoCount;

  /// 여행기 대표 사진 — **내가 그때 찍은 사진**의 기기 내 식별자 (photo_manager `AssetEntity.id`).
  ///
  /// 비어 있으면 '고른 적 없다'는 뜻이고, 목록은 첫 들른 곳의 스팟 사진으로 떨어진다.
  /// ⚠ 사진 자체를 복사해 두지 않는다. 사진첩에서 지워지면 후보에서도 사라진다 —
  ///   여행기가 남의 사진첩을 붙들고 있으면 안 된다 (원칙 5, 기기 안의 기록).
  final String coverPhotoId;

  /// 사진첩에서 직접 고른 대표 사진 — 앱 안에 복사한 파일 **이름** (2026-09-09).
  ///
  /// 여행 시간대 밖의 사진도 대표가 될 수 있어야 해서 시스템 사진 선택기로 고른다.
  /// 선택기는 사진 식별자를 안 주고 복사본을 주니, 앱 문서 폴더 `covers/` 에 둔다.
  /// ⚠ 이름만 저장한다 — Documents 절대경로는 앱을 업데이트하면 바뀐다.
  /// ⚠ [coverPhotoId] 와 둘 중 하나만 산다. 이게 있으면 이걸 먼저 본다.
  final String coverPath;

  /// 거쳐 간 국도 구간 (DR-08). 비어 있으면 옛 기록 — [segmentsOrSelf] 가 출발 국도 하나로 읽는다.
  final List<TripSegment> segments;

  List<TripSegment> get segmentsOrSelf => segments.isNotEmpty
      ? segments
      : [TripSegment(routeId: routeId, routeName: routeName, fromKm: 0, at: startedAt, atEpoch: 0)];

  /// 거쳐 간 국도 번호, 순서대로 (같은 번호가 이어지면 하나로).
  List<int> get routeIds {
    final out = <int>[];
    for (final s in segmentsOrSelf) {
      if (out.isEmpty || out.last != s.routeId) out.add(s.routeId);
    }
    return out;
  }

  /// 지금(마지막) 구간의 국도.
  int get currentRouteId => segmentsOrSelf.last.routeId;

  /// '7번 국도' 또는 '43 → 6번 국도' — 갈아탄 여행은 번호를 잇는다.
  String get routeLabel => routeIds.length <= 1 ? routeName : '${routeIds.join(' → ')}번 국도';

  int get visited => stops.where((s) => s.kind == StopKind.visited).length;
  int get skunked => stops.where((s) => s.kind == StopKind.skunked).length;

  /// 코스에 없던 곳에서 먹은 끼니 (SCREENS.md MY-02).
  ///
  /// **이 앱이 하려는 일이 여기 한 숫자로 들어 있다** — 정해둔 대로가 아니라
  /// 지나다 걸린 곳에서 먹었다는 뜻이다.
  /// ⚠ 코스 없이 그냥 달린 여행은 셀 수 없다. '계획'이 없으면 '계획에 없던'도 없다 → 0.
  int unplannedMeals(Set<String> plannedSpotIds) {
    if (courseId.isEmpty) return 0;
    return stops
        .where(
          (s) =>
              s.kind == StopKind.visited &&
              s.type == SpotType.food &&
              !plannedSpotIds.contains(s.spotId),
        )
        .length;
  }

  /// '7번 국도에서 생긴 일' · 갈아탔으면 '43 → 6번 국도에서 생긴 일'
  String get title => '$routeLabel에서 생긴 일';
}

/// DR-02 근접 발견 카드에 실을 한 건.
extension SpotTimeliness on Spot {
  /// 시의성만 갈아끼운 복사본.
  ///
  /// ⚠ **일몰 시의성은 저장소가 정할 수 없다.** 조회 시점의 하늘(`sun_moon`)에 달려 있고,
  ///   그건 레이더가 위치 격자로 따로 읽는다. 그래서 화면에서 덧입힌다 (`core/sunset.dart`).
  ///   장날·기간임박은 저장소가 그대로 정한다.
  Spot withTimeliness(Timeliness t, String note) => Spot(
    id: id,
    name: name,
    type: type,
    routeId: routeId,
    detourMin: detourMin,
    trustScore: trustScore,
    blurb: blurb,
    timeliness: t,
    timelinessNote: note,
    openHours: openHours,
    tel: tel,
    addr: addr,
    hasPhoto: hasPhoto,
    parking: parking,
    imageUrl: imageUrl,
    lat: lat,
    lng: lng,
    exitFrac: exitFrac,
  );
}

class Discovery {
  const Discovery({
    required this.spot,
    required this.headline,
    required this.lead,
    required this.body,
  });

  final Spot spot;

  /// 존재형 문구. "오늘이 마침 북평 5일장이에요"
  final String headline;

  /// 상황 칩 앞머리. "근처에 있어요" / "일몰 40분 전" / "동해IC 진출로 4분 전 · 오늘만"
  ///
  /// ⚠ 거리는 여기 없다. 저장소는 격자 좌표만 알아서 못 잰다 — 카드가 뜨는 **그 순간**
  ///   레이더가 기기 안에서 현 위치↔스팟 직선거리를 재어 붙인다 (`S.cardSituation`).
  final String lead;
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

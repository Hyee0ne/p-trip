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

class RouteLine {
  const RouteLine({
    required this.id,
    required this.name,
    required this.axis,
    required this.drivable,
    required this.fromTo,
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

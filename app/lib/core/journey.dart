import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';

/// 지금 달리기로 한 것 (CO-08 길 떠나기 · CO-02 코스).
///
/// **국도만 골라도 출발한다.** 코스는 "처음이라 걱정되면" 쪽 진입이고,
/// 주 흐름은 길 하나와 방향 하나다 — 목적지를 묻지 않는다 (원칙 1).
///
/// ⚠ **기기에 저장하지 않는다.** 여정은 그 순간의 일이고, 앱이 죽어도 남아야 하는 건
///   여행 기록(core/trip_log.dart)이지 "지금 뭘 달리는 중인지"가 아니다.
class Journey {
  const Journey({
    required this.routeId,
    required this.routeName,
    required this.path,
    this.courseId = '',
    this.startName = '',
    this.endName = '',
    this.continues = false,
  });

  /// **여행 중 갈아타기** (DR-08). true 면 레이더가 여행을 새로 시작하지 않고 구간만 늘린다 —
  /// 거리·들른 곳·알린 곳이 그대로 이어진다. 발견 탭 「길 떠나기」와 레이더 「길 바꾸기」 둘 다 여기로.
  final bool continues;

  final int routeId;
  final String routeName;

  /// 달릴 선형. 국도면 `route_path_ahead`가, 코스면 코스 선형이 들어온다.
  final List<GeoPoint> path;

  /// 코스로 출발했으면 그 id. 국도만 골랐으면 빈 문자열.
  /// ⚠ "계획에 없던 밥"은 무엇이 계획이었는지를 알아야 세므로 이게 필요하다 (MY-02).
  final String courseId;

  /// 여행 기록에 남길 구간 이름. 국도만 골랐으면 모른다 — 지어내지 않는다.
  final String startName;
  final String endName;
}

final startedJourneyProvider = NotifierProvider<StartedJourney, Journey?>(StartedJourney.new);

class StartedJourney extends Notifier<Journey?> {
  @override
  Journey? build() => null;

  void set(Journey? j) => state = j;
}

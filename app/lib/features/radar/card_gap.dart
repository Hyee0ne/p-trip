import '../../data/models/models.dart';

/// 카드 사이 최소 간격 (2026-09-13).
///
/// 전국 데이터가 차자(스팟 2만) 도심 국도에선 카드가 15초마다 이어졌다 — 그건 재촉이다 (원칙 6).
/// 2026-08-30 에 빈도 제한을 없앤 건 데이터가 7번 국도뿐일 때 레이더가 침묵해 고장처럼 보여서였다.
/// 이제 반대 문제라 **간격**으로 지킨다. 대상을 좁히지는 않는다 — 반경 안은 여전히 다 후보다.
///
/// 규칙: 마지막 카드 뒤로 **2km 또는 3분** 중 하나가 차야 다음 카드가 나온다.
/// 주행 기준(거리·주행 시간)이라 시연 배속을 탄다. 시의성(장날·일몰·기간임박)은 절반 —
/// 지나치면 오늘은 없는 것이라서. 첫 카드는 바로. 백그라운드 알림도 같은 관문을 지난다.
class CardGap {
  CardGap({this.km = 2.0, this.sec = 180});

  final double km;
  final double sec;
  double _lastKm = double.negativeInfinity;
  double _lastSec = double.negativeInfinity;

  /// 지나치면 오늘은 없는 것들. 식사 시간대(mealtime)는 여기 안 든다 — 밥집은 내일도 있다.
  static bool isTimely(Timeliness t) =>
      t == Timeliness.marketDay || t == Timeliness.sunset || t == Timeliness.endingSoon;

  bool allows({
    required double drivenKm,
    required double elapsedSec,
    required Timeliness timeliness,
  }) {
    final f = isTimely(timeliness) ? 0.5 : 1.0;
    return drivenKm - _lastKm >= km * f || elapsedSec - _lastSec >= sec * f;
  }

  void mark({required double drivenKm, required double elapsedSec}) {
    _lastKm = drivenKm;
    _lastSec = elapsedSec;
  }

  void reset() {
    _lastKm = double.negativeInfinity;
    _lastSec = double.negativeInfinity;
  }
}

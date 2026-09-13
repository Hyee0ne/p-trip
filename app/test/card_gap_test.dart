import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/radar/card_gap.dart';

/// 카드 간격 (2026-09-13). 전국 데이터가 차자 카드가 15초마다 이어졌다 — 재촉이다.
void main() {
  test('첫 카드는 바로, 그다음은 2km 또는 3분 뒤', () {
    final g = CardGap();
    expect(g.allows(drivenKm: 0, elapsedSec: 0, timeliness: Timeliness.none), isTrue);
    g.mark(drivenKm: 0, elapsedSec: 0);
    expect(
      g.allows(drivenKm: 0.5, elapsedSec: 30, timeliness: Timeliness.none),
      isFalse,
      reason: '15초 뒤 다음 카드가 오던 문제',
    );
    expect(g.allows(drivenKm: 1.9, elapsedSec: 170, timeliness: Timeliness.none), isFalse);
    expect(
      g.allows(drivenKm: 2.0, elapsedSec: 60, timeliness: Timeliness.none),
      isTrue,
      reason: '거리가 찼다',
    );
    expect(
      g.allows(drivenKm: 0.3, elapsedSec: 180, timeliness: Timeliness.none),
      isTrue,
      reason: '막혀도 시간이 차면',
    );
  });

  test('장날·일몰·기간임박은 절반이면 된다 — 밥집은 아니다', () {
    final g = CardGap()..mark(drivenKm: 10, elapsedSec: 600);
    expect(g.allows(drivenKm: 11, elapsedSec: 620, timeliness: Timeliness.marketDay), isTrue);
    expect(g.allows(drivenKm: 11, elapsedSec: 620, timeliness: Timeliness.sunset), isTrue);
    expect(g.allows(drivenKm: 10.2, elapsedSec: 690, timeliness: Timeliness.endingSoon), isTrue);
    expect(g.allows(drivenKm: 11, elapsedSec: 620, timeliness: Timeliness.mealtime), isFalse);
    expect(g.allows(drivenKm: 11, elapsedSec: 620, timeliness: Timeliness.none), isFalse);
  });

  test('여정이 바뀌면 처음부터', () {
    final g = CardGap()..mark(drivenKm: 50, elapsedSec: 3000);
    expect(g.allows(drivenKm: 50.1, elapsedSec: 3001, timeliness: Timeliness.none), isFalse);
    g.reset();
    expect(g.allows(drivenKm: 0, elapsedSec: 0, timeliness: Timeliness.none), isTrue);
  });
}

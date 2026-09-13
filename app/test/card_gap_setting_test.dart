import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/settings.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/radar/card_gap.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 발견 간격 설정 (2026-09-13). "너무 많다"와 "너무 안 뜬다"가 하루 사이에 나왔다 — 사용자가 고른다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('기본은 보통(2km/3분), 고르면 저장되고 다시 읽힌다', () async {
    final a = ProviderContainer();
    expect(a.read(cardGapProvider), CardGapLevel.normal);
    await a.read(cardGapProvider.notifier).set(CardGapLevel.often);
    a.dispose();

    final b = ProviderContainer();
    addTearDown(b.dispose);
    b.read(cardGapProvider);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(b.read(cardGapProvider), CardGapLevel.often);
  });

  test('세기를 바꾸면 간격이 바로 바뀐다 — 기준점은 그대로', () {
    final g = CardGap()..mark(drivenKm: 0, elapsedSec: 0);
    expect(
      g.allows(drivenKm: 1.2, elapsedSec: 100, timeliness: Timeliness.none),
      isFalse,
      reason: '보통 2km/3분',
    );
    g.configure(km: CardGapLevel.often.km, sec: CardGapLevel.often.sec);
    expect(
      g.allows(drivenKm: 1.2, elapsedSec: 100, timeliness: Timeliness.none),
      isTrue,
      reason: '자주 1km/90s',
    );
    expect(g.remaining(drivenKm: 0.4, elapsedSec: 30).$1, closeTo(0.6, 1e-9));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/data/models/models.dart';

/// 노선에 붙는 한 줄 (CO-01 재설계).
///
/// ⚠ **절대량 인기를 말하지 않는다** (원칙 3). "제일 많이 다니는 길"은 없다 —
///   오늘 장이 서거나(시의성), 요즘 사람들이 더 도는 곳이 있다(변화율)는 사실뿐이다.
void main() {
  test('장날 한 줄은 곳 수에 따라 달라진다', () {
    expect(S.routeNoteMarket(1), '오늘 이 길에 장이 서요');
    expect(S.routeNoteMarket(3), '오늘 이 길에 장이 3곳 서요');
  });

  test('변화율 문구는 개수를 말하지 않는다', () {
    // 몇 곳인지는 안심의 근거로 안에 들고만 있고 문장에는 안 쓴다.
    expect(S.routeNoteRising, '요즘 이 길로 더 도네요');
    expect(S.routeNoteRising.contains(RegExp(r'\d')), isFalse);
  });

  test('절대량을 말하는 표현이 없다', () {
    for (final line in [S.routeNoteMarket(2), S.routeNoteRising]) {
      for (final banned in ['제일', '가장', '인기', '1위', '최다']) {
        expect(line.contains(banned), isFalse, reason: '원칙 3 — 절대량 인기 금지: $banned');
      }
    }
  });

  test('근거는 들고 있되 목록이 아니다', () {
    const n = RouteNote(RouteNoteKind.rising, 19);
    expect(n.spots, 19);
    expect(n.kind, RouteNoteKind.rising);
  });
}

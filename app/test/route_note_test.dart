import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/data/models/models.dart';

/// 노선 한 줄은 **근거마다 다른 말을 해야 한다.**
///
/// ⚠ 2026-09-04: 변화율이 두 시점을 요구하는데 개발계정 한도로 한 시점만 받다 보니
///   전국에서 큐레이션 한 줄이 안 나왔다. 절대 순위를 보조로 허용했다(원칙 3 개정).
///   그런데 절대 순위로 뽑힌 길에 '요즘 이 길로 더 도네요' 를 붙이면 거짓말이 된다 —
///   그 길은 '요즘 더' 도는 게 아니라 흔적이 많은 것뿐이다.
void main() {
  test('세 근거가 모두 다른 문구를 쓴다', () {
    final all = {S.routeNoteMarket(1), S.routeNoteRising, S.routeNotePopular};
    expect(all.length, 3);
  });

  test('흔적 문구는 변화를 주장하지 않는다', () {
    for (final word in ['요즘', '더', '뜨는', '급상승']) {
      expect(S.routeNotePopular, isNot(contains(word)));
    }
  });

  test('흔적 문구는 별점·후기를 말하지 않는다 — 원칙 3의 나머지는 그대로', () {
    for (final word in ['별점', '평점', '후기', '리뷰', '점']) {
      expect(S.routeNotePopular, isNot(contains(word)));
    }
  });

  test('변화 문구는 그대로다 — 관찰한 사실이라 바꿀 이유가 없다', () {
    expect(S.routeNoteRising, '요즘 이 길로 더 도네요');
  });

  test('세 종류가 모두 열거되어 있다', () {
    // 하나라도 빠지면 switch 가 컴파일되지 않는다 — 이 테스트는 의도를 남긴다.
    expect(RouteNoteKind.values, hasLength(3));
    expect(RouteNoteKind.values, contains(RouteNoteKind.popular));
  });
}

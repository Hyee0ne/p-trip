import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/data/models/models.dart';

/// 노선 한 줄은 **근거마다 다른 말을 해야 한다.**
///
/// ⚠ 2026-09-04: 변화율이 두 시점을 요구하는데 개발계정 한도로 한 시점만 받다 보니
///   전국에서 큐레이션 한 줄이 안 나왔다. 절대 순위를 보조로 허용했다(원칙 3 개정).
///   그런데 절대 순위로 뽑힌 길에 변화 문구를 붙이면 거짓말이 된다 —
///   그 길은 '요즘 더' 가는 게 아니라 흔적이 많은 것뿐이다.
///
/// ⚠ 2026-09-07: 변화 문구를 '요즘 이 길로 더 도네요' 에서 바꿨다. 두 가지 이유다.
///   ① '돈다' 가 국도 앱에서 **우회**로 읽힌다 (막혀서 돌아간다).
///   ② 대안으로 나온 '관심이 많아졌어요' 는 데이터보다 약하다 —
///     연관관광지는 실제로 **다녀간 기록**이지 관심이 아니다. 관심은 안 가도 생긴다.
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

  test('두 시점 문구는 최근 기준이라는 것만 말한다 — 증가를 주장하지 않는다', () {
    // 2026-09-16: '발길이 늘었어요' → '함께 찾는 곳이 늘었어요' → '최근에도 함께 찾는 곳이 많아요'.
    // 연관 관광지는 함께 찾은 곳의 **순위**라 방문자 수도 증가량도 모른다. 순위 상승 ≠ 증가.
    expect(S.routeNoteRising, '최근에도 함께 찾는 곳이 많아요');
    expect(S.routeNoteRising, contains('최근'));
    for (final word in ['늘', '증가', '많아졌']) {
      expect(S.routeNoteRising, isNot(contains(word)));
    }
  });

  test("변화 문구는 '관심'이 아니라 발걸음을 말한다", () {
    // 재는 건 관심이 아니라 발걸음이다. '관심'으로 낮춰 말하면 데이터보다 약해지고
    // 동시에 인기·평가 쪽 언어로 흘러간다 — 별점을 안 만든 이유가 그거다 (원칙 3).
    for (final word in ['관심', '인기', '화제', '뜨는', '별점', '평점', '후기', '리뷰']) {
      expect(S.routeNoteRising, isNot(contains(word)));
    }
  });

  test("변화 문구는 '돈다'를 쓰지 않는다 — 국도 앱에서 우회로 읽힌다", () {
    // 실시간 교통정보로 오해될 여지를 남기지 않는다. 이 앱은 그걸 하지 않는다 (원칙 1).
    for (final word in ['도네', '돌아', '우회']) {
      expect(S.routeNoteRising, isNot(contains(word)));
    }
  });

  test('세 종류가 모두 열거되어 있다', () {
    // 하나라도 빠지면 switch 가 컴파일되지 않는다 — 이 테스트는 의도를 남긴다.
    expect(RouteNoteKind.values, hasLength(3));
    expect(RouteNoteKind.values, contains(RouteNoteKind.popular));
  });
}

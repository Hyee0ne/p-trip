import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';

/// 코스를 안 고르고 레이더를 켰을 때 **국도 번호를 지어내지 않는다.**
///
/// ⚠ 2026-09-04: 가평에서 레이더를 켰는데 "7번 국도 0km 기록 중 · 남은 65km"가 떴다.
///   `_routeNo` 가 `?? 7` 이었고, 코스를 안 고르면 데모 코스(삼척-강릉)를 태웠다.
///   스팟이 7번 국도밖에 없던 시절의 설계가 그대로 남아 있었다.
void main() {
  test('노선을 모를 때 쓰는 문구에는 국도 번호가 없다', () {
    final s = S.radarRecordingNoRoute(12);
    expect(s, contains('12km'));
    expect(s, contains('기록'));
    // 번호를 지어내면 안 된다.
    expect(s, isNot(contains('국도')));
    expect(s, isNot(contains('7')));
  });

  test('노선을 알 때는 그 번호를 말한다', () {
    expect(S.radarRecording('43번 국도', 12), contains('43번 국도'));
    expect(S.radarRecording('43번 국도', 12), contains('12km'));
  });

  test('두 문구는 거리를 같은 방식으로 말한다', () {
    // 형식이 갈리면 화면에서 다른 앱처럼 보인다.
    expect(S.radarRecordingNoRoute(5), endsWith('5km 기록 중'));
    expect(S.radarRecording('7번 국도', 5), endsWith('5km 기록 중'));
  });
}

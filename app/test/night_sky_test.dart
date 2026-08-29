import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/data/models/models.dart';

/// 그날 밤 한 줄 (MY-02 §3, TECH_SPEC §3.8).
///
/// ⚠ 단정할 수 있는 것만 말한다. 할 말이 없으면 **줄을 만들지 않는다**.
void main() {
  test('달이 없던 밤은 그렇게 말한다', () {
    expect(const NightSky(moonless: true).line, '그날 밤, 달은 없었습니다.');
  });

  test('달이 떠 있던 밤은 아무 말도 하지 않는다', () {
    // moonset은 그날 아침에 진 달이라 '몇 시에 졌다'를 쓸 수 없다.
    // 틀린 문장보다 없는 줄이 낫다.
    expect(const NightSky(moonless: false).line, isNull);
  });

  test('모르면 지어내지 않는다', () {
    expect(const NightSky().line, isNull);
    expect(const NightSky(eventTitle: '').line, isNull);
  });

  test('천문현상이 달보다 앞선다', () {
    const sky = NightSky(moonless: true, eventTitle: '쌍둥이자리 유성우');
    expect(sky.line, '그날 밤엔 쌍둥이자리 유성우가 쏟아졌습니다.');
  });

  test('유성우가 아니면 담담하게', () {
    expect(const NightSky(eventTitle: '개기월식').line, '그날 밤엔 개기월식이 있었습니다.');
  });

  test('조사를 받침으로 가른다', () {
    // '문'은 받침이 있다 → '이'
    expect(const NightSky(eventTitle: '슈퍼문').line, contains('슈퍼문이 '));
    // '폐'는 받침이 없다 → '가'
    expect(const NightSky(eventTitle: '목성 엄폐').line, contains('엄폐가 '));
  });
}

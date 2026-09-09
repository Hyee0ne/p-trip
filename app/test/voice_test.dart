import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/voice.dart';

/// 낭독 (DR-02). 기기 음성만 쓴다 — 목소리를 고르고, 문장을 다듬는다 (2026-09-09).
void main() {
  group('음성 고르기', () {
    test('한국어 중 premium > enhanced > default', () {
      final picked = Voice.pickVoice([
        {'name': 'Yuna', 'locale': 'ko-KR', 'quality': 'default', 'identifier': 'c'},
        {'name': 'Samantha', 'locale': 'en-US', 'quality': 'premium', 'identifier': 'x'},
        {'name': 'Yuna', 'locale': 'ko-KR', 'quality': 'enhanced', 'identifier': 'e'},
        {'name': 'Yuna', 'locale': 'ko-KR', 'quality': 'premium', 'identifier': 'p'},
      ]);
      expect(picked?['identifier'], 'p', reason: '영어 premium 은 안 잡고 한국어 premium 을 잡는다');
    });

    test('enhanced 만 있으면 enhanced — 압축본보다 낫다', () {
      final picked = Voice.pickVoice([
        {'name': 'Yuna', 'locale': 'ko-KR', 'quality': 'default', 'identifier': 'c'},
        {'name': 'Yuna', 'locale': 'ko-KR', 'quality': 'enhanced', 'identifier': 'e'},
      ]);
      expect(picked?['identifier'], 'e');
    });

    test('한국어 음성이 없으면 null — 언어만 잡고 iOS 가 고르게 둔다', () {
      expect(
        Voice.pickVoice([
          {'name': 'Samantha', 'locale': 'en-US', 'quality': 'premium'},
        ]),
        isNull,
      );
      expect(Voice.pickVoice(const []), isNull);
    });

    test('안드로이드식 ko_KR 도 잡는다', () {
      final picked = Voice.pickVoice([
        {'name': 'ko-kr-x-ism-local', 'locale': 'ko_KR', 'quality': 'default'},
      ]);
      expect(picked, isNotNull);
    });

    test('플랫폼이 Map<Object?, Object?> 로 줘도 깨지지 않는다', () {
      final raw = <dynamic>[
        <Object?, Object?>{'name': 'Yuna', 'locale': 'ko-KR', 'quality': 'enhanced'},
        'garbage',
        null,
      ];
      expect(Voice.pickVoice(raw)?['quality'], 'enhanced');
    });
  });

  group('말하기 전 다듬기 — 화면 문구는 그대로, 소리만', () {
    test('줄바꿈은 공백, 가운뎃점은 쉼표', () {
      expect(
        Voice.shapeForSpeech('곧 추암 촛대바위에\n해가 져요. 일몰 40분 전 · 여기서 약 2.4km'),
        '곧 추암 촛대바위에 해가 져요. 일몰 40분 전, 여기서 약 2.4킬로미터',
      );
    });

    test('거리 단위는 풀어 읽는다 — km 을 먼저, m 은 그 다음', () {
      expect(Voice.shapeForSpeech('근처에 있어요 · 여기서 약 700m'), '근처에 있어요, 여기서 약 700미터');
      expect(Voice.shapeForSpeech('여기서 약 12km'), '여기서 약 12킬로미터');
      // 숫자 뒤가 아니면 건드리지 않는다.
      expect(Voice.shapeForSpeech('km 단위'), 'km 단위');
    });

    test('줄표도 쉼표 — 잠깐 쉬고 넘어간다', () {
      expect(Voice.shapeForSpeech('오늘이 마침 장날이에요 — 북평민속오일장'), '오늘이 마침 장날이에요, 북평민속오일장');
    });

    test('빈 문장은 빈 문장', () {
      expect(Voice.shapeForSpeech('  \n '), '');
    });
  });
}

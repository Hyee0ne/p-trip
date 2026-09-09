import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/os.dart';
import 'package:p_trip/core/strings.dart';

/// 「더 자연스러운 목소리 받기」 — 설정 경로는 iOS 버전을 따라간다 (2026-09-09).
void main() {
  group('iOS 버전 읽기', () {
    test('"Version 26.6 (Build 23G80)" → 26', () {
      expect(osMajorVersion('Version 26.6 (Build 23G80)'), 26);
    });
    test('"Version 18.5 (Build 22F76)" → 18', () {
      expect(osMajorVersion('Version 18.5 (Build 22F76)'), 18);
    });
    test('못 읽으면 0', () {
      expect(osMajorVersion('garbage'), 0);
      expect(osMajorVersion(''), 0);
    });
  });

  group('설정 경로', () {
    test('iOS 26 부터는 「읽기 및 말하기」', () {
      final s = S.voiceBetterSteps(26).join(' > ');
      expect(s, contains('읽기 및 말하기'));
      expect(s, isNot(contains('콘텐츠 말하기')));
    });
    test('그 전엔 「콘텐츠 말하기」', () {
      final s = S.voiceBetterSteps(18).join(' > ');
      expect(s, contains('콘텐츠 말하기'));
      expect(s, isNot(contains('읽기 및 말하기')));
    });
    test('품질 이름은 iOS 그대로 — 지어낸 「고품질」로 끝내지 않는다', () {
      final last = S.voiceBetterSteps(26).last;
      expect(last, '프리미엄 음성 다운로드');
    });
  });
}

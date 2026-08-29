import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 발견 카드 낭독 (SCREENS.md DR-02).
///
/// ⚠ **카카오내비 안내를 끊지 않는다.** 우리가 말할 때만 잠깐 볼륨을 낮추고(duck),
///   끝나면 원래대로 돌려준다. 길안내가 주고 우리는 곁들이는 소리다 —
///   내비가 되지 않는다는 원칙(1)이 소리에서도 같다.
/// ⚠ 짧게 읽는다. 운전 중에 긴 문장을 들려주면 그 자체가 방해다.
class Voice {
  Voice._();
  static final instance = Voice._();

  FlutterTts? _tts;
  bool _failed = false;

  Future<FlutterTts?> _engine() async {
    if (_failed) return null;
    if (_tts != null) return _tts;
    try {
      final t = FlutterTts();
      await t.setLanguage('ko-KR');
      // 운전 중이라 조금 느리게. 기본 속도는 흘려듣기 쉽다.
      await t.setSpeechRate(0.48);
      await t.setVolume(0.9);
      await t.awaitSpeakCompletion(true);
      _tts = t;
      return t;
    } catch (_) {
      // TTS가 없는 기기·테스트 환경. 소리 없이 조용히 넘어간다.
      _failed = true;
      return null;
    }
  }

  Future<void> speak(String text) async {
    final t = await _engine();
    if (t == null || text.trim().isEmpty) return;
    try {
      await t.stop();
      await t.speak(text);
    } catch (_) {
      // 낭독 실패가 화면을 막지 않는다.
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {
      /* 무시 */
    }
  }
}

final voiceProvider = Provider<Voice>((ref) => Voice.instance);

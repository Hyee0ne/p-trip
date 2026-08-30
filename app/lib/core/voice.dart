import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 발견 카드 낭독 (SCREENS.md DR-02).
///
/// ⚠ **카카오내비 안내를 끊지 않는다.** 우리가 말할 때만 잠깐 볼륨을 낮추고(duck),
///   끝나면 원래대로 돌려준다. 길안내가 주고 우리는 곁들이는 소리다 —
///   내비가 되지 않는다는 원칙(1)이 소리에서도 같다.
///   → `setIosAudioCategory(playback, [mixWithOthers, duckOthers])`가 그 약속이다.
///   ⚠ **실기기에서만 확인된다.** 시뮬레이터는 오디오 세션 충돌을 재현하지 않는다.
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
      // ⚠ 이 네 줄이 "내비를 끊지 않는다"의 전부다.
      //   playback + mixWithOthers = 카카오내비 안내와 **같이** 난다 (끊지 않는다).
      //   duckOthers = 우리가 말하는 동안만 상대 볼륨을 낮췄다가 되돌린다.
      //   voicePrompt = 짧은 안내음이라고 iOS에 알려준다 — 음악처럼 취급되지 않게.
      await t.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ], IosTextToSpeechAudioMode.voicePrompt);
      await t.setLanguage('ko-KR');
      // 운전 중이라 조금 느리게. 기본 속도는 흘려듣기 쉽다.
      await t.setSpeechRate(0.48);
      await t.setVolume(0.9);
      await t.awaitSpeakCompletion(true);
      _tts = t;
      return t;
    } catch (e) {
      // TTS가 없는 기기·테스트 환경. 소리 없이 조용히 넘어간다.
      debugPrint('[voice] engine failed: $e');
      _failed = true;
      return null;
    }
  }

  /// 낭독 순서. **앞의 말을 끊지 않고 줄을 세운다.**
  ///
  /// ⚠ 전에는 speak마다 `stop()`을 불러 앞 문장을 잘랐다. 발견을 하나씩 띄우던 시절엔
  ///   문제가 없었는데, 반경 안의 것을 **전부** 알리게 되면서(2026-08-30) 여러 건이
  ///   연달아 들어온다 — 끊으면 마지막 한 조각만 들리고 나머지는 사라진다.
  Future<void> _queue = Future<void>.value();

  Future<void> speak(String text) {
    if (text.trim().isEmpty) return _queue;
    final next = _queue.then((_) => _speakOne(text));
    // 한 건이 실패해도 줄이 끊기지 않게 한다.
    _queue = next.catchError((_) {});
    return _queue;
  }

  Future<void> _speakOne(String text) async {
    final t = await _engine();
    if (t == null) return;
    try {
      // ⚠ **매번 세션을 켠다.** flutter_tts는 카테고리만 잡고 `setActive`를 안 부른다 —
      //   시뮬레이터는 그래도 소리가 나지만 **실기기는 조용하다.** 여기가 그 차이였다.
      //   낭독이 끝나면 플러그인이 알아서 notifyOthersOnDeactivation으로 내린다
      //   (autoStopSharedSession 기본 true) — 그래서 내비 볼륨이 도로 올라온다.
      await t.setSharedInstance(true);
      // awaitSpeakCompletion(true) 라서 여기서 **끝날 때까지 기다린다** — 그게 줄의 근거다.
      await t.speak(text);
    } catch (e) {
      // 낭독 실패가 화면을 막지 않는다.
      debugPrint('[voice] speak failed: $e');
    }
  }

  /// 지금 말하는 것을 멈추고 **줄도 비운다** (여행을 끝냈을 때 등).
  Future<void> stop() async {
    _queue = Future<void>.value();
    try {
      await _tts?.stop();
    } catch (_) {
      /* 무시 */
    }
  }
}

final voiceProvider = Provider<Voice>((ref) => Voice.instance);

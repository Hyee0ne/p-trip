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
///
/// **기기 음성만 쓴다** (2026-09-09 결정). 클라우드 TTS(ElevenLabs 등)는 품질이 위지만
/// 국도 음영지역에서 끊기고, 낭독 문장에 스팟 이름이 들어가 "지금 어디 근처에 있다"가
/// 외부로 나간다 — 위치정보 문의에서 "외부 제공 없음"으로 정리한 것과 어긋난다.
class Voice {
  Voice._();
  static final instance = Voice._();

  FlutterTts? _tts;
  bool _failed = false;

  /// 고른 음성이 고품질(enhanced·premium)인가. 엔진이 뜨기 전엔 null.
  bool? _highQuality;

  /// 등급 순위. 같은 '유나'라도 iOS 에 세 등급이 있고 기본은 압축본이다 — 그게 로봇 소리의 원인.
  /// enhanced·premium 은 **사용자가 설정에서 내려받아야** 생긴다. 앱이 대신 받을 수 없다.
  static const _rank = {'premium': 3, 'enhanced': 2, 'default': 1};

  /// 한국어 음성 중 가장 좋은 것. 없으면 null — 그땐 언어만 잡고 iOS 가 고르게 둔다.
  ///
  /// [voices] 는 `getVoices()` 결과 그대로 (플랫폼 맵 목록). 키·값을 문자열로 정규화해 본다.
  @visibleForTesting
  static Map<String, String>? pickVoice(Iterable<dynamic> voices) {
    Map<String, String>? best;
    var bestRank = 0;
    for (final raw in voices) {
      if (raw is! Map) continue;
      final v = {for (final e in raw.entries) '${e.key}': '${e.value}'};
      // iOS 는 'ko-KR', 안드로이드는 'ko_KR' 로 온다.
      final locale = (v['locale'] ?? '').replaceAll('_', '-').toLowerCase();
      if (!locale.startsWith('ko')) continue;
      final r = _rank[v['quality']] ?? 1;
      if (r > bestRank) {
        bestRank = r;
        best = v;
      }
    }
    return best;
  }

  /// 말하기 직전에 다듬는다. **화면 문구는 그대로 두고 소리만 고친다.**
  ///
  /// 카드 문구가 그대로 들어오는데 기호가 섞여 있다 — 헤드라인의 `\n`은 어색하게 끊기고,
  /// '근처에 있어요 · 국도에서 4분' 의 가운뎃점은 읽거나 삼킨다. 쉼표면 잠깐 쉬고 넘어간다.
  @visibleForTesting
  static String shapeForSpeech(String text) => text
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s*[·•]\s*'), ', ')
      .replaceAll(RegExp(r'\s*[—–]\s*'), ', ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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

      // 목소리를 고른다. 안 고르면 iOS 가 압축본을 잡는다.
      // ⚠ flutter_tts 에서 getVoices 는 함수가 아니라 **getter** 다.
      final voices = await t.getVoices;
      final picked = pickVoice(voices is List ? voices : const []);
      if (picked != null) {
        await t.setVoice({
          'name': picked['name'] ?? '',
          'locale': picked['locale'] ?? 'ko-KR',
          // identifier 가 있으면 플러그인이 그걸로 정확히 잡는다 (이름·언어 검색보다 확실하다).
          if ((picked['identifier'] ?? '').isNotEmpty) 'identifier': picked['identifier']!,
        });
        _highQuality = picked['quality'] == 'enhanced' || picked['quality'] == 'premium';
      } else {
        _highQuality = false;
      }

      // ⚠ 0.48 은 오히려 더 기계적으로 들렸다 — 늘어지는 만큼 합성음 티가 난다.
      //   유나 음성엔 0.5 + 살짝 높은 피치가 자연스럽다. 실기기로 듣고 맞춘 값이다.
      await t.setSpeechRate(0.5);
      await t.setPitch(1.05);
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

  /// 설정 화면이 「더 자연스러운 목소리 받기」를 보여줄지 정할 때 쓴다.
  /// 엔진을 못 띄우면(테스트·시뮬레이터) null — **모르면 안 보여준다.**
  Future<bool?> probeQuality() async {
    await _engine();
    return _highQuality;
  }

  /// 낭독 순서. **앞의 말을 끊지 않고 줄을 세운다.**
  ///
  /// ⚠ 전에는 speak마다 `stop()`을 불러 앞 문장을 잘랐다. 발견을 하나씩 띄우던 시절엔
  ///   문제가 없었는데, 반경 안의 것을 **전부** 알리게 되면서(2026-08-30) 여러 건이
  ///   연달아 들어온다 — 끊으면 마지막 한 조각만 들리고 나머지는 사라진다.
  Future<void> _queue = Future<void>.value();

  Future<void> speak(String text) {
    final shaped = shapeForSpeech(text);
    if (shaped.isEmpty) return _queue;
    final next = _queue.then((_) => _speakOne(shaped));
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

/// 고품질 음성이 깔려 있는가. false 면 MY-03 이 「더 자연스러운 목소리 받기」를 보여준다.
/// null(모름)이면 안 보여준다 — 눌러도 할 게 없는 행을 남기지 않는다.
final voiceQualityProvider = FutureProvider<bool?>((ref) => Voice.instance.probeQuality());

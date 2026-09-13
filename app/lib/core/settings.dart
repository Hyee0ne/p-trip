import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';

/// 기기 설정. 전부 SharedPreferences 하나에 산다.
///
/// **데모 모드 = 모의 주행.** 실제 코스 선형 위를 배속으로 달려 심사위원 앞에서
/// 65km를 몇 분에 보여준다. 끄면 진짜 GPS를 쓴다 (core/drive.dart `startLive`).
///
/// ⚠ 기본값이 true인 이유: 이 앱은 달려야 뭔가 보인다. 책상에서 처음 켠 사람에게
///   빈 화면을 주지 않는다. 진짜 운전할 사람은 마이 탭에서 끄면 된다.
const _kDemoMode = 'demoMode.v1';

final demoModeProvider = NotifierProvider<DemoModeNotifier, bool>(DemoModeNotifier.new);

class DemoModeNotifier extends Notifier<bool> {
  SharedPreferences? _prefs;
  Future<void>? _ready;
  bool _dirty = false;

  @override
  bool build() {
    // 데모를 못 쓰는 빌드(출시)면 저장값과 무관하게 항상 실주행이다.
    if (!Env.demoAvailable) return false;
    _ready = _restore();
    return Env.demoDefault;
  }

  Future<void> _restore() async {
    if (!Env.demoAvailable) return;
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      final v = p.getBool(_kDemoMode);
      // 복원 전에 사용자가 이미 껐으면 덮어쓰지 않는다 (trip_log.dart와 같은 규칙).
      if (v == null || _dirty) return;
      state = v;
    } catch (_) {
      // 저장소를 못 열어도 앱은 돈다. 이번 실행에만 기본값으로 남는다.
    }
  }

  /// 저장값 복원이 끝났는가. **판단하기 전에 기다릴 것.**
  ///
  /// ⚠ 이 프로바이더는 처음 읽는 순간 만들어지고, `build()` 는 기본값(켜짐)을 **먼저** 돌려준 뒤
  ///   저장값을 비동기로 덮어쓴다. 앱을 켜고 마이 탭을 안 거친 채 바로 출발하면 레이더가
  ///   첫 독자가 되어 **꺼 둔 데모 모드를 켜진 걸로 읽었다** — 시트 없이 모의 주행이 돌고
  ///   "데모 모드라 안내 없이 켰어요"가 떴다 (2026-09-09 실기기, 43번 국도). 이걸 기다리면 없다.
  Future<void> get ready => _ready ?? Future<void>.value();

  Future<void> set(bool v) async {
    _dirty = true;
    state = v;
    await _ready;
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setBool(_kDemoMode, v);
  }
}

/// DR-06 백그라운드 근접 알림 on/off.
///
/// ⚠ 기본값 **false**. 허용해야만 켜진다 — 심사노트의 "기본값이 꺼짐"이 이 줄이다.
/// ⚠ **묻는 자리는 출발할 때 한 번뿐이다** (2026-09-08, SCREENS.md DR-01 진입).
///   전에는 여행을 2번 마친 사람이 레이더 🔔을 눌러야 물었다 — 국도 여행 앱에서
///   2번 완주는 몇 주라, 사실상 아무도 닿지 못했다. 온보딩에서는 여전히 안 묻는다.
/// ⚠ 여기서 끄면 알림만 멈춘다 — OS 권한은 건드리지 않는다.
const _kBgAlerts = 'bgAlerts.on.v1';

/// OS 에 알림 권한을 **물어본 적이 있는가.** iOS 는 평생 한 번만 묻는다.
/// ⚠ 이 플래그가 없으면 출발할 때마다 `requestPermissions` 를 부르게 되고,
///   허용했던 사람이 마이에서 꺼 둔 걸 매 출발마다 다시 켜 버린다.
const _kNotifAsked = 'notif.asked.v1';

final backgroundAlertsProvider = NotifierProvider<BackgroundAlertsNotifier, bool>(
  BackgroundAlertsNotifier.new,
);

class BackgroundAlertsNotifier extends Notifier<bool> {
  SharedPreferences? _prefs;
  Future<void>? _ready;
  bool _dirty = false;
  bool _asked = false;

  @override
  bool build() {
    _ready = _restore();
    return false;
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      _asked = p.getBool(_kNotifAsked) ?? false;
      final v = p.getBool(_kBgAlerts);
      if (v == null || _dirty) return;
      state = v;
    } catch (_) {
      /* 못 열면 꺼진 채로 둔다 — 안 물어본 걸 켜놓지 않는다 */
    }
  }

  Future<void> set(bool v) async {
    _dirty = true;
    state = v;
    await _ready;
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setBool(_kBgAlerts, v);
  }

  /// OS 팝업을 **한 번만** 띄운다. 이미 물었으면 아무것도 안 하고 지금 값을 돌려준다.
  ///
  /// [request] 는 실제로 OS 에 묻는 함수다 (`ProximityAlerts.requestPermission`).
  /// 여기서 직접 부르지 않는 건 설정 파일이 알림 플러그인을 알 이유가 없어서다.
  Future<bool> askOnce(Future<bool> Function() request) async {
    await _ready;
    if (_asked) return state;
    _asked = true;
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setBool(_kNotifAsked, true);
    } catch (_) {
      /* 플래그를 못 남겨도 이번 실행에선 다시 안 묻는다 */
    }
    final ok = await request();
    await set(ok);
    return ok;
  }

  /// 물어본 적이 있는가 — MY-03 토글이 "거절됐으니 설정으로" 를 가르는 데 쓴다.
  bool get asked => _asked;
}

// ── 온보딩 (ON — 최초 1회) ──
const _kOnboardingDone = 'onboarding.done.v1';

/// 온보딩을 봤는지. **시작하기·건너뛰기 둘 다** 본 것으로 적는다 — 다시 보여주는 게 재촉이다.
///
/// ⚠ 2026-09-09 까지 `/onboarding` 라우트만 있고 첫 실행에 거기로 보내는 코드가 없었다.
///   출시 앱(1.0.0·1.0.1)에서 온보딩이 한 번도 안 떴다. 그 사용자들은 업데이트 뒤 한 번 본다.
class Onboarding {
  static Future<bool> isDone() async =>
      (await SharedPreferences.getInstance()).getBool(_kOnboardingDone) ?? false;

  static Future<void> markDone() async =>
      (await SharedPreferences.getInstance()).setBool(_kOnboardingDone, true);

  /// 앱의 첫 화면. 개발용 `START_AT` 을 명시했으면 그게 이긴다 — 화면 확인이 온보딩에 막히면 안 된다.
  static Future<String> initialLocation() async {
    if (Env.startAtSet) return Env.startAt;
    return await isDone() ? Env.startAt : '/onboarding';
  }
}

// ── 발견 간격 (DR-02 카드 간격, 2026-09-13) ──
const _kCardGap = 'cardGap.v1';

/// 카드 사이 최소 간격의 세기. 실기기에서 "너무 많다"(간격 없음)와 "너무 안 뜬다"(2km/3분)가 하루 사이에
/// 나왔다 — 길·속도·취향에 따라 다르니 사용자가 고른다. 보통이 기본이다.
enum CardGapLevel {
  often(km: 1.0, sec: 90),
  normal(km: 2.0, sec: 180),
  rare(km: 4.0, sec: 360);

  const CardGapLevel({required this.km, required this.sec});
  final double km;
  final double sec;
}

final cardGapProvider = NotifierProvider<CardGapNotifier, CardGapLevel>(CardGapNotifier.new);

class CardGapNotifier extends Notifier<CardGapLevel> {
  @override
  CardGapLevel build() {
    unawaited(_restore());
    return CardGapLevel.normal;
  }

  bool _dirty = false;

  Future<void> _restore() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_kCardGap);
      if (v == null || _dirty) return;
      state = CardGapLevel.values.firstWhere((e) => e.name == v, orElse: () => CardGapLevel.normal);
    } catch (_) {
      /* 못 읽으면 보통 */
    }
  }

  Future<void> set(CardGapLevel v) async {
    _dirty = true;
    state = v;
    try {
      await (await SharedPreferences.getInstance()).setString(_kCardGap, v.name);
    } catch (_) {
      /* 이번 실행에만 남는다 */
    }
  }
}

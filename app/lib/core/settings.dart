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

/// 한 번 고른 길안내 앱 (HND, 2026-09-08).
///
/// 다음 출발부터는 그 앱 버튼 하나만 크게 보이고 「다른 앱으로」 로 바꿀 수 있다.
/// ⚠ 티맵은 뺐다 — 카카오내비와 애플 지도 둘뿐이다. 심사에서 요구한 건 애플 지도다.
enum NavApp { kakao, apple }

const _kNavApp = 'nav.app.v1';

final navAppProvider = NotifierProvider<NavAppNotifier, NavApp?>(NavAppNotifier.new);

class NavAppNotifier extends Notifier<NavApp?> {
  SharedPreferences? _prefs;
  Future<void>? _ready;
  bool _dirty = false;

  @override
  NavApp? build() {
    _ready = _restore();
    return null;
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      final v = p.getString(_kNavApp);
      if (v == null || _dirty) return;
      state = NavApp.values.where((e) => e.name == v).firstOrNull;
    } catch (_) {
      /* 못 열면 안 고른 셈 — 다음 출발에 두 버튼이 보일 뿐이다 */
    }
  }

  Future<void> set(NavApp app) async {
    _dirty = true;
    state = app;
    await _ready;
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(_kNavApp, app.name);
  }
}

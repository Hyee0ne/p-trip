import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';

/// 기기 설정. 지금은 데모 모드 하나뿐이라 파일 하나로 충분하다.
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
    _ready = _restore();
    return Env.demoDefault;
  }

  Future<void> _restore() async {
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
/// ⚠ 기본값 **false**. 권한 피로 = 이탈이라, 먼저 묻지 않는다 (SCREENS.md DR-06 1단계).
///   여행을 2번 마친 사람이 레이더 상단 🔔을 눌렀을 때만 물어본다.
/// ⚠ 여기서 끄면 알림만 멈춘다 — OS 권한은 건드리지 않는다.
const _kBgAlerts = 'bgAlerts.on.v1';

final backgroundAlertsProvider = NotifierProvider<BackgroundAlertsNotifier, bool>(
  BackgroundAlertsNotifier.new,
);

class BackgroundAlertsNotifier extends Notifier<bool> {
  SharedPreferences? _prefs;
  Future<void>? _ready;
  bool _dirty = false;

  @override
  bool build() {
    _ready = _restore();
    return false;
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
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
}

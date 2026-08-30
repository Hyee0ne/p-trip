import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/models.dart';

/// DR-06 백그라운드 근접 알림.
///
/// **앞에 있을 때와 같은 발견을 같은 빈도로 내보낸다** (2026-08-30 결정).
/// 원래는 "장날·일몰·기간임박"만 내보냈다 — 꺼둔 앱이 말을 걸 이유는 '오늘만' 뿐이라는
/// 이유였다. 실기기 주행에서 뒤집혔다: 앞에 카카오내비를 띄우고 달리면 앱은 뒤에 있지만
/// **사용자는 여행 중**이다. '꺼둔 앱'이 아니다. 그 상태에서 침묵하면 레이더가 고장 난 것처럼 보인다.
///
/// 남은 규칙:
/// - 30분에 2번까지 (화면 안 쿨다운 §3.1 6번과 **같은 값**)
/// - 이동이 40분 없으면 스스로 접는다
///
/// ⚠ 횟수를 **기기에 남긴다**. 메모리에만 두면 앱을 껐다 켜서 제한을 우회하게 된다.
/// ⚠ 설정에서 끄면 알림만 멈춘다 — OS 권한은 건드리지 않는다 (우리가 뺏을 것이 아니다).
class ProximityAlerts {
  ProximityAlerts._();
  static final instance = ProximityAlerts._();

  static const _kState = 'bgAlerts.v2';

  /// 화면 안 쿨다운(§3.1 6번)과 **같은 값**이어야 한다. 뒤에 있다고 덜 말하지 않는다.
  static const _window = Duration(minutes: 30);
  static const _maxInWindow = 2;

  /// 이동이 이만큼 없으면 스스로 접는다.
  static const foldAfter = Duration(minutes: 40);

  FlutterLocalNotificationsPlugin? _plugin;
  bool _failed = false;

  /// 최근 발신 시각들. 30분 창 안의 것만 남긴다.
  final List<DateTime> _sentAt = [];
  bool _restored = false;

  Future<FlutterLocalNotificationsPlugin?> _engine() async {
    if (_failed) return null;
    if (_plugin != null) return _plugin;
    try {
      final p = FlutterLocalNotificationsPlugin();
      await p.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // ⚠ 여기서 권한을 묻지 않는다. 묻는 시점은 DR-06a 유도 화면 하나뿐이다.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _plugin = p;
      return p;
    } catch (_) {
      // 알림을 못 써도 주행은 굴러간다.
      _failed = true;
      return null;
    }
  }

  /// OS 권한 요청. **DR-06a에서 사용자가 [허용하러 가기]를 눌렀을 때만** 부른다.
  Future<bool> requestPermission() async {
    final p = await _engine();
    if (p == null) return false;
    try {
      final ios = p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      final android = p
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kState);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      for (final s in (m['sentAt'] as List?) ?? const []) {
        final at = DateTime.tryParse(s as String);
        if (at != null) _sentAt.add(at);
      }
    } catch (_) {
      /* 못 읽으면 오늘 처음인 셈 친다 */
    }
  }

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _kState,
        jsonEncode({
          'sentAt': [for (final a in _sentAt) a.toIso8601String()],
        }),
      );
    } catch (_) {
      /* 저장 실패가 주행을 막지 않는다 */
    }
  }

  /// 지금 내보내도 되는가. 조건을 하나라도 어기면 false — **조용히** 넘어간다.
  ///
  /// 알림 플러그인 없이도 규칙만 따로 검증할 수 있게 열어둔다 (test/proximity_test.dart).
  @visibleForTesting
  Future<bool> allowed(DateTime now) async {
    await _restore();
    _sentAt.removeWhere((a) => now.difference(a) >= _window);
    return _sentAt.length < _maxInWindow;
  }

  /// 발견 하나를 알림으로. 조건에 안 맞으면 아무 일도 안 일어난다.
  ///
  /// [head]·[title]은 DR-02 카드에 뜨는 문구 그대로 쓴다 — 화면과 알림이 다른 말을 하면 안 된다.
  Future<void> notify({
    required Spot spot,
    required String head,
    required String title,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    if (!await allowed(at)) return;
    final p = await _engine();
    if (p == null) return;

    try {
      await p.show(
        spot.id.hashCode & 0x7fffffff,
        head,
        title,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'proximity',
            '근처 발견',
            channelDescription: '달리는 동안 앞쪽에 오늘만 볼 수 있는 곳이 있을 때',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // 탭하면 그 카드를 연다.
        payload: 'spot:${spot.id}',
      );
      await markSent(at);
    } catch (_) {
      /* 알림 실패가 주행을 막지 않는다 */
    }
  }

  /// 테스트끼리 횟수가 새지 않게. **운영 코드에서 부르지 않는다** —
  /// 실행 중에 세는 걸 지우면 하루 제한이 무의미해진다.
  @visibleForTesting
  void debugReset() {
    _sentAt.clear();
    _restored = false;
  }

  /// 한 건 내보냈다고 적는다. 이게 30분·하루 4회 제한의 기준점이다.
  @visibleForTesting
  Future<void> markSent(DateTime at) async {
    // ⚠ **먼저 읽어온다.** 안 읽고 적으면 나중 _restore 가 저장본을 다시 얹어
    //   같은 발신이 두 번 세어지고, 30분에 2회 제한이 1회처럼 동작한다.
    await _restore();
    _sentAt
      ..removeWhere((a) => at.difference(a) >= _window)
      ..add(at);
    await _save();
  }

  /// 40분간 이동이 없어 스스로 접을 때. **무음**이다 — 접었다는 사실만 남긴다.
  Future<void> foldUp(String text) async {
    final p = await _engine();
    if (p == null) return;
    try {
      await p.show(
        0,
        text,
        null,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'proximity',
            '근처 발견',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
          ),
          iOS: DarwinNotificationDetails(presentSound: false),
        ),
      );
    } catch (_) {
      /* 무시 */
    }
  }
}

final proximityAlertsProvider = Provider<ProximityAlerts>((_) => ProximityAlerts.instance);

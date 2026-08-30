import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';

/// DR-06 백그라운드 근접 알림.
///
/// **앞에 있을 때와 같은 발견을 같은 빈도로 내보낸다** (2026-08-30 결정).
/// 원래는 "장날·일몰·기간임박"만 내보냈다 — 꺼둔 앱이 말을 걸 이유는 '오늘만' 뿐이라는
/// 이유였다. 실기기 주행에서 뒤집혔다: 앞에 카카오내비를 띄우고 달리면 앱은 뒤에 있지만
/// **사용자는 여행 중**이다. '꺼둔 앱'이 아니다. 그 상태에서 침묵하면 레이더가 고장 난 것처럼 보인다.
///
/// **빈도 제한도 없앴다** (2026-08-30). 반경 안에 들어온 건 다 알린다 —
/// 걸러내는 건 오직 `_shown`(같은 곳을 두 번 말하지 않는다)과 반경뿐이다.
///
/// 남은 규칙:
/// - 같은 스팟은 한 번만 (레이더가 `_shown`으로 막는다)
/// - 이동이 40분 없으면 스스로 접는다
/// ⚠ 설정에서 끄면 알림만 멈춘다 — OS 권한은 건드리지 않는다 (우리가 뺏을 것이 아니다).
class ProximityAlerts {
  ProximityAlerts._();
  static final instance = ProximityAlerts._();

  /// 이동이 이만큼 없으면 스스로 접는다.
  static const foldAfter = Duration(minutes: 40);

  FlutterLocalNotificationsPlugin? _plugin;
  bool _failed = false;

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

  /// 발견 하나를 알림으로. 조건에 안 맞으면 아무 일도 안 일어난다.
  ///
  /// [head]·[title]은 DR-02 카드에 뜨는 문구 그대로 쓴다 — 화면과 알림이 다른 말을 하면 안 된다.
  Future<void> notify({required Spot spot, required String head, required String title}) async {
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
    } catch (_) {
      /* 알림 실패가 주행을 막지 않는다 */
    }
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

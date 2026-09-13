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
        // 알림을 누르면 그 스팟으로 (2026-09-13). 앱이 뒤에 살아 있을 때 여기로 온다.
        onDidReceiveNotificationResponse: (r) => handleTap(r.payload),
      );
      _plugin = p;
      return p;
    } catch (_) {
      // 알림을 못 써도 주행은 굴러간다.
      _failed = true;
      return null;
    }
  }

  /// 알림을 눌렀을 때 갈 경로(`/spot/{id}` · `/radar`)를 넘기는 손잡이. 앱이 라우터를 만든 뒤 [attach] 로 꽂는다.
  void Function(String route)? onOpen;

  /// 라우터가 생기기 전에 눌린 알림. [attach] 때 처리한다.
  String? _pending;

  /// `spot:<id>` 페이로드에서 id 를 뽑는다. 접힘 알림(페이로드 없음)은 null — 갈 데가 없다.
  static String? spotIdOf(String? payload) {
    if (payload == null || !payload.startsWith('spot:')) return null;
    final id = payload.substring(5).trim();
    return id.isEmpty ? null : id;
  }

  /// 페이로드 → 갈 경로. 스팟 알림은 상세, 「앞쪽에 갈 만한 곳」(DR-07) 알림은 레이더. 모르면 null.
  static String? routeOf(String? payload) {
    final id = spotIdOf(payload);
    if (id != null) return '/spot/$id';
    if (payload == 'next') return '/radar';
    return null;
  }

  /// 알림 탭. 플러그인 콜백(앱이 살아 있을 때)과 콜드 스타트(앱이 알림으로 켜질 때) 둘 다 여기로 온다.
  ///
  /// ⚠ 소리를 듣고 바로 못 눌러도 알림은 알림 센터에 남는다 — 나중에 눌러도 그 스팟으로 간다.
  ///   기획(DR-06)엔 "탭 → 해당 카드"라고 적혀 있었지만 처리 코드가 없어서 앱만 열렸다 (2026-09-13 실기기).
  void handleTap(String? payload) {
    final route = routeOf(payload);
    if (route == null) return;
    final open = onOpen;
    if (open == null) {
      _pending = route;
      return;
    }
    open(route);
  }

  /// 라우터가 준비되면 한 번 부른다. 앱이 **알림으로 켜졌으면** 그 스팟으로 간다.
  Future<void> attach(void Function(String route) open) async {
    onOpen = open;
    final p = await _engine();
    String? launched;
    try {
      final d = await p?.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp == true) launched = d!.notificationResponse?.payload;
    } catch (_) {
      /* 못 읽어도 앱은 뜬다 */
    }
    final route = _pending ?? routeOf(launched);
    _pending = null;
    if (route != null) open(route);
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

  /// DR-07 — 들른 뒤 정차 중 앞쪽 후보가 열렸는데 앱이 뒤에 있을 때. 눌러 레이더로 온다 (`next`).
  /// ⚠ 한 정차에 한 번. 재촉이 아니라 "열려 있다"는 알림이다.
  Future<void> notifyNext({required String title, required String body}) async {
    final p = await _engine();
    if (p == null) return;
    try {
      await p.show(
        1,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails('proximity', '근처 발견'),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'next',
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

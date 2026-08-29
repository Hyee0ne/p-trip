import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/models.dart';

/// DR-06 백그라운드 근접 알림.
///
/// **꺼둔 앱이 말을 걸 이유는 "오늘만" 뿐이다.** 그래서 규칙이 화면 안 쿨다운보다 엄하다:
/// - 장날·일몰·기간임박 중 하나일 때만 (일반 스팟은 절대 안 내보낸다 — 재촉 금지 원칙)
/// - 30분에 1번, 하루 4번
/// - 이동이 40분 없으면 스스로 접는다
///
/// ⚠ 횟수를 **기기에 남긴다**. 메모리에만 두면 앱을 껐다 켜서 하루 제한을 우회하게 된다.
/// ⚠ 설정에서 끄면 알림만 멈춘다 — OS 권한은 건드리지 않는다 (우리가 뺏을 것이 아니다).
class ProximityAlerts {
  ProximityAlerts._();
  static final instance = ProximityAlerts._();

  static const _kState = 'bgAlerts.v1';
  static const _minGap = Duration(minutes: 30);
  static const _dailyMax = 4;

  /// 이동이 이만큼 없으면 스스로 접는다.
  static const foldAfter = Duration(minutes: 40);

  FlutterLocalNotificationsPlugin? _plugin;
  bool _failed = false;

  DateTime? _lastAt;
  String _day = '';
  int _sentToday = 0;
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
      _day = (m['day'] as String?) ?? '';
      _sentToday = (m['sent'] as num?)?.toInt() ?? 0;
      final at = m['lastAt'] as String?;
      _lastAt = at == null ? null : DateTime.tryParse(at);
    } catch (_) {
      /* 못 읽으면 오늘 처음인 셈 친다 */
    }
  }

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _kState,
        jsonEncode({'day': _day, 'sent': _sentToday, 'lastAt': _lastAt?.toIso8601String()}),
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
    final today = _dayKey(now);
    if (today != _day) {
      _day = today;
      _sentToday = 0;
    }
    if (_sentToday >= _dailyMax) return false;
    if (_lastAt != null && now.difference(_lastAt!) < _minGap) return false;
    return true;
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
    // ⚠ 시의성 없는 스팟은 백그라운드로 내보내지 않는다. 이 한 줄이 원칙이다.
    if (spot.timeliness == Timeliness.none) return;

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
    _lastAt = null;
    _day = '';
    _sentToday = 0;
    _restored = false;
  }

  /// 한 건 내보냈다고 적는다. 이게 30분·하루 4회 제한의 기준점이다.
  @visibleForTesting
  Future<void> markSent(DateTime at) async {
    // ⚠ 날짜를 **여기서도** 찍는다. 안 찍으면 횟수는 4인데 날짜가 비어 있어,
    //   다음 검사에서 "날이 바뀌었네" 하고 카운트가 0으로 풀린다.
    _day = _dayKey(at);
    _lastAt = at;
    _sentToday++;
    await _save();
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

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

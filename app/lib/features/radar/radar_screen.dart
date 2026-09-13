import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/drive.dart';
import '../../core/env.dart';
import '../../core/geo.dart';
import '../../core/journey.dart';
import '../../core/location.dart';
import '../../core/saves.dart';
import '../../core/proximity_alert.dart';
import '../../core/settings.dart';
import '../../core/strings.dart';
import '../../core/sunset.dart';
import '../../core/theme.dart';
import '../../core/trip_log.dart';
import '../../core/voice.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../handoff/handoff_sheet.dart';
import 'card_gap.dart';
import 'radar_next.dart';
import 'radar_stops.dart';
import 'radar_switch.dart';
import 'radar_view.dart';

/// DR-01 레이더 모드 (SCREENS.md DR-01). 다크 테마 고정.
///
/// ⚠ 경로 추종 화면이 아니다. 이탈 알림·재탐색·ETA가 없다 (원칙 1·2).
/// ⚠ 뷰 토글이 없다 — 운전 중엔 언제나 한 곳씩.
class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});
  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> with WidgetsBindingObserver {
  Timer? _nextCard;

  /// 15초 무응답 타이머. 카드가 사라지면 같이 꺼진다.
  Timer? _noAnswer;
  bool _cardVisible = false;
  bool _voiceOn = true;
  bool _started = false;

  /// 이미 내보낸 발견. 같은 카드를 두 번 띄우지 않는다.
  final _shown = <String>{};

  /// 직전에 내보낸 유형. 같은 유형을 연속으로 내보내지 않는다 (§3.1 6번).

  /// 카드를 내보낸 주행 시각(분). 30분당 2회 상한을 재는 데 쓴다.

  /// 오늘 이 자리의 해·달. 일몰 가중치가 쓴다.
  TodaySky? _sky;

  /// 지금 화면에 떠 있는 발견.
  Discovery? _current;

  /// 카드 사이 간격 (card_gap.dart). 여정이 바뀌면 처음부터.
  final _gap = CardGap();

  // ── DR-07 「여기서 앞쪽으로」 (radar_next.dart) ──
  bool _nextOpen = false;

  /// 정차로 **자동으로** 펼친 것인가 — 다시 달리면 접는다. 손으로 연 건 손으로 닫는다.
  bool _nextAuto = false;
  bool _nextLoading = false;
  List<Discovery> _next = const [];

  /// 레이더(5km)보다 넓게 본다 — 서 있으니 시간이 있다.
  static const _nextKm = 10.0;

  /// 들르기 뒤 이만큼 서 있으면 자동으로 펼친다. 밥 먹고 돌아오면 이미 열려 있다.
  static const _nextStopSec = 120.0;

  /// [_current] 가 뜬 **그 순간**의 현 위치↔스팟 직선거리(km). 좌표가 없으면 null.
  /// ⚠ 한 번 재고 갱신하지 않는다 — 줄어드는 숫자는 카운트다운이다 (원칙 6).
  double? _currentKm;

  /// 카드를 띄우는 구간 — 진출로까지 3~7분 (TECH_SPEC §3.1 5번).
  /// 너무 이르면 잊어버리고, 너무 늦으면 상의할 시간이 없다.
  /// 발견을 내보내는 **반경(km)**. 진행 방향으로 이 안에 들어오면 알린다.
  ///
  /// ⚠ 2026-08-30: '3~7분 앞'에서 바꿨다. 시간 기준은 속도를 타서, 막히면 코앞만 뜨고
  ///   뻥 뚫리면 한참 먼 게 떴다. 거리 기준이라야 "여기서 N km 안"이 말이 된다.
  static const _aheadKm = 5.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠ 탭 셸이 IndexedStack이라 이 화면은 다른 탭에 있어도 살아 있다.
    //   TickerMode를 보고 실제로 보일 때만 주행을 돌린다.
    //   안 그러면 발견 탭에 있는 동안에도 GPS 로깅이 도는 셈이 된다.
    // ⚠ **여기서 provider를 바로 건드리면 안 된다.** `_setRunning` 이 drive·tripLog 를
    //   수정하는데, didChangeDependencies 는 위젯 생애주기라 Riverpod 이 막는다
    //   ("Tried to modify a provider while the widget tree was building").
    //   전에는 코스를 불러오는 `.then()` 안이라 우연히 비켜 갔고, 코스 없이 바로
    //   시작하도록 고치자 화면이 통째로 빨간 오류가 됐다 (2026-09-04).
    final enabled = TickerMode.valuesOf(context).enabled;
    Future.microtask(() {
      if (mounted) _setRunning(enabled);
    });
  }

  /// 앱이 뒤에 있는가. 알림을 켠 사람만 뒤에서도 주행이 돈다.
  bool _background = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final on = ref.read(backgroundAlertsProvider);
    // ⚠ `inactive`를 내려간 걸로 보면 안 된다. 알림 창을 내리거나 앱 전환기를 열 때도,
    //   권한 팝업이 뜰 때도 오는 상태다 — 그때마다 주행을 끊으면 레이더가 멋대로 죽는다.
    final away = s == AppLifecycleState.paused || s == AppLifecycleState.hidden;

    if (away) {
      // 알림을 안 켠 사람은 뒤에서 위치를 보지 않는다. 켠 사람만 계속 돈다.
      if (!on) {
        ref.read(driveProvider.notifier).stop();
      } else {
        // ⚠ 주행 도중에 설정을 켰다면 스트림이 아직 포그라운드 설정이다.
        //   여기서 맞춰주지 않으면 켠 줄 알고 기다리는데 iOS가 앱을 재운다.
        ref.read(driveProvider.notifier).setBackground(true);
      }
      _background = on;
      return;
    }
    if (s != AppLifecycleState.resumed) return;

    _background = false;
    // ⚠ 돌아왔으면 **다시 달린다.** 이게 없으면 앱을 한 번 내린 순간 그 세션 내내
    //   레이더가 죽어 있다 — _started가 true라 시작 경로도 막혀 있다.
    ref.read(driveProvider.notifier).resume();
  }

  /// 레이더가 **실제로 도는가.** 내비 앱을 고른 순간(또는 이미 길 위일 때) 켜진다.
  /// 그전엔 화면은 보여도 위치도 서버도 건드리지 않는다 (SCREENS.md DR-01 진입, 2026-09-08).
  bool _armed = false;

  /// 이번 여정에서 핸드오프 시트를 이미 띄웠는가. 탭을 오갈 때마다 다시 띄우지 않는다.
  bool _offered = false;

  /// 위 플래그들이 어느 여정의 것인지. 새 여정이 오면 전부 되돌린다 —
  /// 이 화면은 탭 셸(IndexedStack) 안에서 계속 살아 있어서, 안 되돌리면 두 번째 여행이 안 켜진다.
  Journey? _flagsFor;

  /// 이보다 가까우면 이미 국도 위다 — 안내할 게 없다. CO-08 과 같은 값.
  static const _entryThresholdKm = 0.3;

  /// 진입 때 위치를 기다려 주는 시간. 넘으면 시트를 띄운다 — 화면을 붙잡지 않는다.
  static const _locWait = Duration(seconds: 3);

  void _resetForJourney(Journey? next) {
    if (identical(next, _flagsFor)) return;
    // DR-08 — 여행 중 갈아타기. 여정만 바꾸고 여행·거리·알린 곳은 그대로 잇는다.
    if (next != null && next.continues && _started) {
      _applySwitch(next);
      return;
    }
    _flagsFor = next;
    _armed = false;
    _offered = false;
    _nextCard?.cancel();
    _noAnswer?.cancel();
    _started = false;
    _shown.clear();
    _gap.reset();
    _nextOpen = false;
    _nextAuto = false;
    _next = const [];
  }

  /// 「다음」 원을 눌렀을 때 / 정차로 자동 펼침. 열면 앞쪽을 새로 본다.
  void _toggleNext({bool auto = false}) {
    if (_nextOpen && !auto) {
      setState(() {
        _nextOpen = false;
        _nextAuto = false;
      });
      return;
    }
    setState(() {
      _nextOpen = true;
      _nextAuto = auto;
    });
    unawaited(_loadNext());
  }

  /// 정차 2분 + 들른 곳이 있으면 자동으로 펼치고, 다시 달리면(자동으로 연 것만) 접는다.
  /// 들른 곳이 없어도 **5분** 서 있으면 펼친다 — 카드 없이 세운 곳도 밥집일 수 있다 (2026-09-13).
  /// ⚠ 정차 판정은 `DriveNotifier.isStill` — 속도만 보면 GPS 가 튀어 영영 안 찬다.
  void _maybeAutoNext(DriveState d) {
    if (!d.running) return;
    final stops = ref.read(tripLogProvider).active?.stops ?? const <TripStop>[];
    final hasVisited = stops.any((s) => s.kind == StopKind.visited);
    final due = (hasVisited && d.stoppedSec >= _nextStopSec) || d.stoppedSec >= _nextStopSec * 2.5;
    if (!_nextOpen && !_cardVisible && due) {
      _toggleNext(auto: true);
    } else if (_nextOpen && _nextAuto && d.stoppedSec < 5) {
      setState(() {
        _nextOpen = false;
        _nextAuto = false;
      });
    }
  }

  /// 현재 위치에서 **원래 진행 방향**으로 10km. 방향은 여정 선형에서 — 서 있으면 GPS 헤딩이 흔들린다.
  /// 좌표는 저장소가 0.01° 격자로 뭉개서 보낸다 (위치정보 문의와 같은 규칙).
  Future<void> _loadNext() async {
    final drive = ref.read(driveProvider);
    final journey = ref.read(startedJourneyProvider);
    if (!drive.hasFix || journey == null) return;
    setState(() => _nextLoading = true);
    final heading = routeBearingAt(journey.path, drive.lat!, drive.lng!) ?? drive.headingDeg;
    try {
      final q = await ref
          .read(discoverRepositoryProvider)
          .radarQueue(lat: drive.lat!, lng: drive.lng!, headingDeg: heading, km: _nextKm);
      if (!mounted) return;
      final visitedIds = {
        for (final s in ref.read(tripLogProvider).active?.stops ?? const <TripStop>[]) s.spotId,
      };
      final now = DateTime.now();
      final list = pickNextAhead(
        [for (final d in q) applySunset(d, _sky, now)],
        {..._shown, ...visitedIds},
        _score,
      );
      setState(() {
        _next = list;
        _nextLoading = false;
      });
      // 앱이 뒤에 있으면(티맵이 앞) 열린 줄 모른다 — 알림 한 번. 눌러 레이더로 온다 (DR-07).
      if (_nextAuto && _background && list.isNotEmpty) {
        unawaited(
          ref
              .read(proximityAlertsProvider)
              .notifyNext(title: S.nextNotifTitle, body: S.nextNotifBody(list.length)),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _nextLoading = false);
    }
  }

  /// 후보의 「들르기」 — 카드와 같은 핸드오프. 앱을 골랐을 때만 들른 곳으로 적는다.
  Future<void> _visitNext(Discovery d) async {
    final app = await HandoffSheet.show(
      context,
      mode: HandoffMode.visit,
      destination: HandoffPlace(d.spot.name, d.spot.lat, d.spot.lng),
    );
    if (!mounted || app == null) return;
    ref.read(tripLogProvider.notifier).addStop(d.spot, StopKind.visited);
    _shown.add(d.spot.id);
    setState(() {
      _nextOpen = false;
      _nextAuto = false;
    });
  }

  // ── DR-08 길 바꾸기 ──

  /// 갈아탄 여정을 적용한다 — 구간 추가 · 선형 교체 · 새 길 진입점까지 핸드오프. 여행은 그대로다.
  void _applySwitch(Journey j) {
    final drive = ref.read(driveProvider);
    ref
        .read(tripLogProvider.notifier)
        .switchRoute(routeId: j.routeId, routeName: j.routeName, atKm: drive.distanceKm);
    ref.read(driveProvider.notifier).switchPath(j.path);
    _flagsFor = j;
    _nextOpen = false;
    _nextAuto = false;
    _next = const [];
    if (mounted) setState(() {});
    _sayNoNav(S.switchedTo(j.routeId));
    // 데모는 시트 없이 새 선형을 바로 달린다. 실주행은 출발 때처럼 진입점까지 티맵.
    if (!ref.read(demoModeProvider)) unawaited(_openHandoff(j));
  }

  /// 상단 국도 뱃지를 누르면 — 여기서 탈 수 있는 국도 목록. 홈과 같은 조회다.
  Future<void> _openRouteSwitch() async {
    final drive = ref.read(driveProvider);
    final journey = ref.read(startedJourneyProvider);
    if (journey == null || !drive.hasFix) return;
    final result = await ref
        .read(discoverRepositoryProvider)
        .nearbyRoutes(lat: drive.lat!, lng: drive.lng!);
    if (!mounted) return;
    final picked = await RouteSwitchSheet.show(
      context,
      currentRouteId: journey.routeId,
      result: result,
    );
    if (picked == null || !mounted) return;
    await _switchTo(picked.$1, picked.$2);
  }

  Future<void> _switchTo(RouteLine route, bool northOrEast) async {
    final drive = ref.read(driveProvider);
    if (!drive.hasFix) return;
    final path = await ref
        .read(discoverRepositoryProvider)
        .routePathAhead(
          routeId: route.id,
          lat: drive.lat!,
          lng: drive.lng!,
          northOrEast: northOrEast,
        );
    if (!mounted) return;
    if (path.length < 2) {
      showAppToast(context, S.departNoPath);
      return;
    }
    ref
        .read(startedJourneyProvider.notifier)
        .set(
          Journey(
            routeId: route.id,
            routeName: route.name.isEmpty ? S.routeNumber(route.id) : route.name,
            path: path,
            continues: true,
          ),
        );
  }

  /// 「그냥 N번 국도로 돌아가기」 — 출발 때와 같은 핸드오프. 목적지는 원래 방향의 국도 진입점.
  Future<void> _backToRoute() async {
    final drive = ref.read(driveProvider);
    final journey = ref.read(startedJourneyProvider);
    if (journey == null || !drive.hasFix) return;
    final path = await ref
        .read(discoverRepositoryProvider)
        .routePathAhead(
          routeId: journey.routeId,
          lat: drive.lat!,
          lng: drive.lng!,
          northOrEast: pathGoesNorthOrEast(journey.path),
        );
    if (!mounted) return;
    final entry = path.isNotEmpty ? path.first : journey.path.first;
    await HandoffSheet.show(
      context,
      mode: HandoffMode.depart,
      destination: HandoffPlace(journey.routeName, entry.lat, entry.lng),
      routeId: journey.routeId,
    );
    if (!mounted) return;
    setState(() {
      _nextOpen = false;
      _nextAuto = false;
    });
  }

  void _setRunning(bool run) {
    if (!run) {
      ref.read(driveProvider.notifier).stop();
      return;
    }
    final journey = ref.read(startedJourneyProvider);
    // ⓪ 길을 안 골랐다. **아무것도 돌지 않는다** — 스윕도, 위치도, 서버 요청도.
    //   전에는 여기서 코스 없이 레이더를 돌렸다(`routeId: 0`). 그 분기를 통째로 지웠다.
    // ⚠ 앱을 껐다 켜면 여정은 없다 — 달리던 여행은 `trip_log` 가 '끝난 여행'으로 남기고
    //   (activeId 는 저장하지 않는다), 레이더는 여기로 온다. 복원하지 않는다.
    if (journey == null) return;

    if (_armed) {
      _start(journey);
      return;
    }
    _offerHandoff(journey);
  }

  /// 진입 직후 한 번 — 이미 길 위면 바로 켜고, 아니면 핸드오프 시트를 띄운다.
  ///
  /// ⚠ 데모는 시연용이다. 시뮬레이터엔 내비가 없어 고를 수가 없으니 바로 돈다 (개발 빌드뿐).
  Future<void> _offerHandoff(Journey journey) async {
    if (_offered) return;
    _offered = true;
    // ⚠ 데모 모드는 **저장값이 복원된 뒤에** 본다. 첫 독자가 레이더면 기본값(켜짐)이 먼저 와서
    //   꺼 둔 데모가 켜진 걸로 읽혔다 (2026-09-09 실기기). settings.dart `ready` 참조.
    await ref.read(demoModeProvider.notifier).ready;
    if (!mounted) return;
    if (ref.read(demoModeProvider) || journey.path.length < 2) {
      // 데모 모드는 시트 없이 돈다 — 시연 리허설에서 내비를 열지 않고도 레이더를 봐야 한다.
      final demo = ref.read(demoModeProvider);
      _arm(journey);
      if (demo) _sayNoNav(S.radarNoNavDemo);
      return;
    }
    // 한 번만 재고, 못 재면 시트를 띄운다. 기다리느라 화면을 붙잡지 않는다.
    final fix = await ref
        .read(currentLocationProvider.future)
        .timeout(_locWait, onTimeout: () => const LocFix(LocStatus.unavailable));
    if (!mounted) return;
    final entry = journey.path.first;
    if (fix.hasFix && roughKm(fix.lat!, fix.lng!, entry.lat, entry.lng) <= _entryThresholdKm) {
      // 이미 그 길 위다 — 100m 앞을 목적지로 내비를 열면 켜자마자 '도착'이라 더 이상하다.
      _arm(journey);
      _sayNoNav(S.radarNoNavOnRoute(journey.routeId));
      return;
    }
    await _openHandoff(journey);
  }

  /// 핸드오프 시트. **고르면 켜진다.** 내리면 하단에 「내비로 안내받기」 만 남는다.
  ///
  /// ⚠ 목적지는 **그 길의 진입점**이다 — 선형의 끝을 잡으면 내비가 최단 경로로
  ///   안내해서 고속도로로 빠진다. 국도를 타려고 켠 내비가 국도를 벗어나게 만드는 셈이다.
  Future<void> _openHandoff(Journey journey) async {
    final entry = journey.path.first;
    final app = await HandoffSheet.show(
      context,
      mode: HandoffMode.depart,
      destination: HandoffPlace(journey.routeName, entry.lat, entry.lng),
      // 제목이 '{N}번 국도로 안내를 시작해요' 가 되게. 앱 이름이 아니라 길 이름으로 말한다.
      routeId: journey.routeId,
    );
    if (!mounted) return;
    if (app != null) {
      _arm(journey);
    } else {
      setState(() {});
    }
  }

  /// 시트를 **건너뛴 이유**를 토스트로 말한다 (2026-09-09). 말 안 하면 오류처럼 보였다 —
  /// 43번 국도 위에서 출발했더니 시트가 안 떠 놀랐다 (실기기). 진입 때 한 번, 지나가는 배너로.
  void _sayNoNav(String message) {
    if (mounted) showAppToast(context, message);
  }

  void _arm(Journey journey) {
    if (!_armed && mounted) setState(() => _armed = true);
    _start(journey);
  }

  void _start(Journey journey) {
    if (_started) return;
    _started = true;
    // ⚠ 모의 주행도 **실제 선형**을 따라간다. 좌표를 지어내지 않는다.
    //   데모 모드를 끄면 같은 선형 위를 진짜 GPS로 달린다 (마이 탭 설정).
    _begin(journey.path, ref.read(demoModeProvider));
    // 이미 진행 중인 여행이 있으면(복원) 그걸 돌려준다 — 새로 만들지 않는다.
    ref
        .read(tripLogProvider.notifier)
        .start(
          routeId: journey.routeId,
          routeName: journey.routeName,
          startName: journey.startName,
          endName: journey.endName,
          courseId: journey.courseId,
        );
  }

  /// 모의 주행이냐 실주행이냐만 가른다. 선형은 이미 정해져 온다.
  void _begin(List<GeoPoint> path, bool demo) {
    if (demo) {
      // 복원한 여정은 선형이 없다 — 모의 주행을 시킬 길이 없으니 멈춘 채 둔다 (개발 빌드뿐).
      if (path.length < 2) return;
      ref.read(driveProvider.notifier).start(path);
    } else {
      // 알림을 켰으면 앱을 내려도 위치가 계속 온다 (DR-06).
      ref
          .read(driveProvider.notifier)
          .startLive(path, background: ref.read(backgroundAlertsProvider));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nextCard?.cancel();
    _noAnswer?.cancel();
    super.dispose();
  }

  /// 진행률이 바뀔 때마다 **앞에 있는 발견**을 고른다.
  /// 시간으로 띄우지 않는다 — 어디를 지나고 있느냐가 기준이다.
  ///
  /// 창에 여럿이 걸리면 **타이밍 가중치**로 고른다 (§3.1 4번):
  /// 장날인 시장 ×3 / 일몰 −60~−20분 뷰포인트 ×2 / 11–14시 음식점 ×2.
  /// 그래서 시연 대본의 "장날 카드 → 일몰 카드"가 우연이 아니라 규칙으로 나온다.
  void _pickAhead(DriveState drive, List<Discovery> queue) {
    if (_cardVisible || _current != null || queue.isEmpty || !drive.running) return;
    if (!Env.autoCard) return;
    // 레이더를 먼저 보여준 뒤 발견이 다가온다. 바로 덮으면 레이더를 못 본다 (SCREENS DR-01).
    if (drive.elapsedSec < 4) return;

    Discovery? best;
    var bestScore = 0.0;
    final now = DateTime.now();
    // 큐는 이미 **현 위치 반경 _aheadKm, 진행 방향 ±60°**로 걸러져 온다
    // (discover_ahead RPC). 여기서 거리로 **거르지** 않는다 — 칩에 적는 거리는 보여주는 값이다 (_kmFromHere).
    // ⚠ 전에는 exit_frac 으로 쟀는데, 그건 **그 스팟이 속한 노선의** 비율이라
    //   다른 국도를 달리면 뺄셈 자체가 말이 안 됐다 (43번 위에서 7번 스팟이 뜬 이유).
    // ⚠ '같은 유형 연속 금지'는 폐기했다 (2026-08-30). 빈도 제한이 없어진 마당에
    //   유형으로 거르면 남은 게 전부 같은 유형일 때 아무것도 안 나가고 굶는다.
    for (final raw in queue) {
      if (_shown.contains(raw.spot.id)) continue;
      // ⚠ **여기서 일몰을 덧입힌다** (core/sunset.dart). 저장소는 하늘을 모른다.
      //   이걸 빼면 실데이터에서 Timeliness.sunset이 한 번도 안 붙어
      //   DR-02 일몰 카드도, DR-06 일몰 알림도 영영 안 나온다.
      final d = applySunset(raw, _sky, now);
      // 간격이 안 찼으면 이번엔 안 내보낸다 — 지나가면서 다시 본다. 시의성은 절반이면 된다.
      if (!_gap.allows(
        drivenKm: drive.distanceKm,
        elapsedSec: drive.elapsedSec,
        timeliness: d.spot.timeliness,
      )) {
        continue;
      }
      final score = _score(d.spot);
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    if (best == null) return;

    _shown.add(best.spot.id);
    _gap.mark(drivenKm: drive.distanceKm, elapsedSec: drive.elapsedSec);

    // DR-06 — 앱이 뒤에 있으면 카드 대신 **음성 + 알림**으로 나간다 (2026-08-29 결정).
    // ⚠ 대상도 빈도도 앞에 있을 때와 같다 (2026-08-30). 거르는 건 반경과 `_shown` 뿐이다.
    if (_background) {
      // 앞에 있을 때와 **같은 발견을** 내보낸다 (2026-08-30 결정, SCREENS.md DR-06).
      // 운전 중엔 배너를 읽을 수 없어 소리가 본 채널이고 알림은 나중에 볼 흔적이다.
      if (_voiceOn) {
        ref
            .read(voiceProvider)
            .speak(
              '${best.headline}. ${S.cardSituation(best.lead, _kmFromHere(drive, best.spot))}',
            );
      }
      ref
          .read(proximityAlertsProvider)
          .notify(spot: best.spot, head: best.headline, title: best.spot.name);
      return;
    }

    _current = best;
    _currentKm = _kmFromHere(drive, best.spot);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 그 사이 여행을 마쳤으면 내보내지 않는다.
      if (!mounted || !ref.read(driveProvider).running) return;
      setState(() => _cardVisible = true);
      _announce(best!);
    });
  }

  /// 타이밍 가중치 (§3.1 4번). 점수를 **화면에 내보내지 않는다** — 순서를 정하는 데만 쓴다.
  /// ⚠ [spot]은 `applySunset`을 **거친** 것이어야 한다. 일몰 판정을 여기서 또 하면
  ///   점수와 알림 게이트가 서로 다른 값을 보게 된다 — 그게 원래 버그였다.
  double _score(Spot spot) {
    final now = DateTime.now();
    var score = 1.0;
    if (spot.hasPhoto) score += 0.5; // 사진 없는 카드는 전면 카드로 약하다

    if (spot.timeliness == Timeliness.marketDay && spot.type == SpotType.market) {
      score *= 3;
    } else if (spot.timeliness == Timeliness.sunset) {
      // 일몰 −60~−20분. 해가 지는 걸 보러 가려면 도착할 시간이 있어야 한다.
      score *= 2;
    } else if (spot.type == SpotType.food && now.hour >= 11 && now.hour < 14) {
      score *= 2;
    }
    return score;
  }

  /// 카드가 뜨는 **이 순간** 현 위치↔스팟 직선거리(km). **기기 안에서만 잰다** — 정확한 좌표는
  /// 서버로 안 간다 (docs/위치정보_문의.md). 좌표를 모르면 null — 숫자를 지어내지 않는다.
  /// ⚠ 분으로 바꾸지 않는다. 그건 도착 예정이고 원칙 1이 막는다.
  static double? _kmFromHere(DriveState d, Spot s) {
    if (!d.hasFix || s.lat == null || s.lng == null) return null;
    return roughKm(d.lat!, d.lng!, s.lat!, s.lng!);
  }

  /// 0.1도 격자로 반올림. sun_moon 캐시가 그 단위다.
  static double _grid(double v) => (v * 10).roundToDouble() / 10;

  /// 레이더 조회 키. **주행 좌표를 그대로 쓰면 안 된다** — 10m마다 바뀌어
  /// family가 매번 새 provider를 만들고 영원히 로딩에 머문다.
  /// 0.01도(약 1.1km)와 30도로 뭉갠다. 반경이 5km라 그 정도 움직였을 때만 다시 묻는다.
  ({double lat, double lng, double? heading, double km})? _queueKey(DriveState d) {
    if (!d.hasFix) return null;
    return (
      lat: (d.lat! * 100).roundToDouble() / 100,
      lng: (d.lng! * 100).roundToDouble() / 100,
      heading: (d.headingDeg / 30).roundToDouble() * 30,
      km: _aheadKm,
    );
  }

  /// GPS 로그와 주행 거리를 여행 기록에 남긴다.
  /// ⚠ 매 프레임 쓰지 않는다 — 0.5km마다 한 점이면 여행기를 그리기에 충분하다.
  double _lastLoggedKm = -1;

  /// 마지막으로 점을 찍은 **실시간**. 정차 구간을 경로에 남기는 기준이다.
  DateTime _lastLoggedAt = DateTime.now();

  /// 40분간 이동이 없으면 레이더를 접는다 (SCREENS.md DR-06).
  /// ⚠ 주행 시간 기준이다 — 시연 배속과 무관해야 한다.
  /// ⚠ 무음 알림 한 번. 접었다는 사실만 남기고 아무것도 재촉하지 않는다.
  bool _folded = false;

  void _maybeFold(DriveState drive) {
    if (_folded || !_background) return;
    if (drive.stoppedSec < ProximityAlerts.foldAfter.inSeconds) return;
    _folded = true;
    ref.read(proximityAlertsProvider).foldUp(S.bgStopped);
    ref.read(driveProvider.notifier).stop();
  }

  void _record(DriveState drive) {
    if (!drive.running || !drive.hasFix) return;
    final log = ref.read(tripLogProvider.notifier);
    log.updateDistance(drive.distanceKm);
    // ⚠ 거리만으로 찍으면 **멈춰 있는 동안이 경로에서 통째로 사라진다.**
    //   사진은 대개 멈춰서 찍는다 — 정차 구간이 없으면 사진을 시각으로 꽂을 수가 없다.
    //   그래서 0.5km마다 **또는** 2분마다 (실시간 기준 — 사진 시각도 실시간이다).
    final now = DateTime.now();
    final movedEnough = drive.distanceKm - _lastLoggedKm >= 0.5;
    final waitedEnough = now.difference(_lastLoggedAt).inSeconds >= 120;
    if (!movedEnough && !waitedEnough) return;
    _lastLoggedKm = drive.distanceKm;
    _lastLoggedAt = now;
    log.logPoint(drive.lat!, drive.lng!);
  }

  /// 진행률 기준으로 **앞에 있는** 발견만 추린다. 이미 지나친 건 레이더에서 뺀다.
  List<Spot> _aheadSpots(List<Discovery> queue) {
    final frac = ref.read(driveProvider).frac;
    final ahead = [
      for (final d in queue)
        if ((d.spot.exitFrac ?? 0) > frac) d.spot,
    ];
    // 앞에 아무것도 없으면(도착) 마지막 몇 개를 남겨 화면이 비지 않게 한다.
    final pick = ahead.isEmpty ? [for (final d in queue) d.spot].reversed.toList() : ahead;
    return pick.take(8).toList();
  }

  /// 낭독 + 무응답 타이머 (SCREENS.md DR-02).
  ///
  /// ⚠ 15초는 **실시간**이다. 쿨다운·정차와 달리 이건 여정이 아니라
  ///   **사람의 반응 시간**이라 시연 배속과 무관해야 한다.
  void _announce(Discovery d) {
    if (_voiceOn) {
      // 헤드 + 상황 한 줄만. 본문까지 읽으면 운전 중에 길다.
      ref.read(voiceProvider).speak('${d.headline}. ${S.cardSituation(d.lead, _currentKm)}');
    }
    _armNoAnswer(d);
  }

  /// 15초 무응답 타이머. 찜을 누르면 다시 센다 — 반응이 있었다.
  void _armNoAnswer(Discovery d) {
    _noAnswer?.cancel();
    _noAnswer = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_cardVisible || _current?.spot.id != d.spot.id) return;
      // ⚠ 무응답은 '지나쳤다'이지 '담았다'가 아니다. 안 한 결정을 대신 하지 않는다.
      _advance(saved: false);
    });
  }

  void _advance({required bool saved}) {
    final current = _current;
    if (current == null) return;

    _noAnswer?.cancel();
    ref.read(voiceProvider).stop();

    // saved = 들르기. ⚠ 찜은 여기로 안 온다 (2026-09-09) — 찜은 카드를 닫지도, 들른 곳으로 적지도 않는다.
    final log = ref.read(tripLogProvider.notifier);
    if (saved) {
      log.addStop(current.spot, StopKind.visited);
    }
    // ⚠ ✕ / 무시는 **아무것도 남기지 않는다** (2026-09-07). 예전엔 '스쳐간 발견'으로
    //   적립했는데, 담은 적 없는 목록이 불어나 정작 찜을 밀어냈다.
    //   재촉하지 않는다는 원칙(6)은 그대로다 — 그냥 지나가는 것도 재촉이 아니다.
    setState(() {
      _cardVisible = false;
      _current = null;
      _currentKm = null;
    });
    // 카드가 사라지고 바로 다음 걸 띄우지 않는다. 다음 발견이 앞에 올 때까지 기다린다.
    _nextCard?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final drive = ref.watch(driveProvider);
    // 발견 간격 설정(자주·보통·가끔) — 바뀌면 바로 반영. 기준점은 그대로.
    final gapLevel = ref.watch(cardGapProvider);
    _gap.configure(km: gapLevel.km, sec: gapLevel.sec);
    // ⚠ 위치를 잡기 전에는 물어볼 좌표가 없다. 그렇다고 **스피너로 덮지 않는다** —
    //   아래 data 분기가 DR-00('위치를 못 받는다')을 이미 말해준다.
    //   덮으면 이유도 모른 채 도는 원만 보인다.
    final key = _queueKey(drive);
    final queueAsync = key == null
        ? const AsyncValue<List<Discovery>>.data([])
        : ref.watch(radarQueueProvider(key));
    // 일몰 가중치용. 격자 단위라 위치가 조금 움직여도 같은 값을 재사용한다.
    if (drive.hasFix) {
      _sky = ref.watch(todaySkyProvider((lat: _grid(drive.lat!), lng: _grid(drive.lng!)))).value;
    }
    final journey = ref.watch(startedJourneyProvider);
    final active = ref.watch(tripLogProvider).active;
    // 새 여정이 오면 켜짐·시트·시작 플래그를 전부 되돌린다. 안 그러면 두 번째 여행이 안 켜진다.
    ref.listen(startedJourneyProvider, (_, next) => _resetForJourney(next));
    // ⚠ build 안에서 provider를 고치면 안 된다 (Riverpod). 주행이 바뀔 때만 반응한다.
    ref.listen(driveProvider, (_, next) {
      _record(next);
      _maybeFold(next);
      // ⚠ **뒤에 있을 땐 build가 안 돈다.** 그래서 여기서 키를 다시 만들어 read 한다 —
      //   watch 에만 기대면 백그라운드에서 큐가 그 자리에 얼어붙는다.
      final k = _queueKey(next);
      _maybeAutoNext(next);
      _pickAhead(next, k == null ? const [] : (ref.read(radarQueueProvider(k)).value ?? const []));
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 어두운 배경엔 밝은 상태바 (pro-rules: 다크 대비)
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.darkBg,
        body: SafeArea(
          bottom: false,
          child: queueAsync.maybeWhen(
            orElse: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            data: (queue) {
              // DR-00 — 실주행인데 위치를 못 받는다. 레이더는 위치가 전부라
              // 빈 화면을 보여주느니 이유를 말하고 길을 둘 다 열어둔다.
              if (drive.needsLocation) return _needsLocation();
              // ⓪ 길을 안 골랐다 (SCREENS.md DR-01 진입). 아무것도 돌지 않는다.
              if (journey == null && active == null) return _idle();
              final current = _current;
              final visited = [
                for (final s in ref.watch(tripLogProvider).active?.stops ?? const <TripStop>[])
                  if (s.kind == StopKind.visited) s,
              ];
              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      _topBar(),
                      const SizedBox(height: AppSpace.x4),
                      _radar(queue),
                      const SizedBox(height: AppSpace.x5),
                      // 「오늘 들른 곳」 자취 — 들른 곳이 없으면 아예 없다 (radar_stops.dart).
                      if (visited.isNotEmpty) ...[
                        StopsTrail(stops: visited, nextOpen: _nextOpen, onNext: _toggleNext),
                        // DR-07 — 「다음」을 열었거나 정차로 열렸을 때만. 카드가 떠 있으면 카드가 위에 있다.
                        if (_nextOpen) ...[
                          const SizedBox(height: AppSpace.x3),
                          NextAhead(
                            routeId: journey?.routeId ?? active?.routeId ?? 0,
                            items: _next,
                            loading: _nextLoading,
                            kmOf: (s) => _kmFromHere(drive, s),
                            onVisit: _visitNext,
                            onOpen: (d) => context.push('/radar/spot/${d.spot.id}'),
                            onBackToRoute: _backToRoute,
                          ),
                        ],
                        const SizedBox(height: AppSpace.x5),
                      ],
                      _notRouteNotice(),
                      // 테스트 빌드에만 — "안 뜨는 게 간격 때문인가, 후보가 없어서인가"를 눈으로 본다.
                      if (Env.demoAvailable) _diagLine(queue, drive),
                      const SizedBox(height: AppSpace.x8),
                      // 내비 앱을 고르기 전엔 마칠 여행이 없다 — 시트를 다시 여는 버튼만.
                      if (_armed) _finishButton() else _handoffButton(),
                    ],
                  ),
                  if (_cardVisible && current != null)
                    _DiscoveryCard(
                      discovery: current,
                      situation: S.cardSituation(current.lead, _currentKm),
                      onVisit: () {
                        // ⚠ 거점을 없앴다 (2026-09-07). **누른 곳이 목적지다.**
                        //   전에는 거점을 목적지로 두고 이 발견을 경유지로 넘겼다.
                        HandoffSheet.show(
                          context,
                          mode: HandoffMode.visit,
                          destination: HandoffPlace(
                            current.spot.name,
                            current.spot.lat,
                            current.spot.lng,
                          ),
                        );
                        // ⚠ **주행을 멈추지 않는다** (2026-09-09). 전에는 여기서 `pause()` 를 불렀다 —
                        //   지운 DR-03 몰아보기의 '정차' 조건을 만들려던 잔재였는데, 그 탓에
                        //   카카오내비로 넘어간 순간부터 `_pickAhead` 가 `!running` 으로 빠져
                        //   **다음 발견이 하나도 안 나갔다.** 앱에 돌아와야 resume 으로 살아났다.
                        //   레이더는 현재 위치 기준이다 (원칙 2) — 들르러 가는 길에도 계속 본다.
                        _advance(saved: true);
                      },
                      liked: ref.watch(savesProvider).isLiked(SaveRef.spot(current.spot.id)),
                      onSave: () {
                        // ⚠ **카드는 그대로 둔다** (2026-09-09). 찜하고 들르기도 할 수 있어야 한다 —
                        //   전에는 찜이 카드를 닫고 '들른 곳'으로까지 적었다. 찜은 찜일 뿐이다.
                        final liked = ref
                            .read(savesProvider.notifier)
                            .toggleLike(SaveRef.spot(current.spot.id));
                        if (liked) showAppToast(context, S.toastSaved);
                        _armNoAnswer(current);
                      },
                      onSkip: () => _advance(saved: false),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// ⚠ 막지 않는다. 설정으로 보내거나 데모로 보거나 — 고르는 건 사용자다.
  Widget _needsLocation() => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.my_location, size: 30, color: AppColors.darkInk2),
          const SizedBox(height: AppSpace.x4),
          const Text(
            S.radarNeedsLocation,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.5, height: 1.6, color: AppColors.darkInk),
          ),
          const SizedBox(height: AppSpace.x5),
          Wrap(
            spacing: AppSpace.x2,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppTouch.min),
                  side: const BorderSide(color: AppColors.darkLine),
                  foregroundColor: AppColors.darkInk,
                ),
                onPressed: Geolocator.openAppSettings,
                child: const Text(S.radarOpenSettings),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppTouch.min),
                  backgroundColor: AppColors.routeBlue,
                ),
                onPressed: () {
                  ref.read(demoModeProvider.notifier).set(true);
                  _started = false;
                  _setRunning(true);
                },
                child: const Text(S.radarUseDemo),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  /// 지금 달리는 노선 번호. 여정에서, 없으면 기록 중인 여행에서.
  ///
  /// ⚠ **모르면 null이다. 7을 박지 않는다.** 전에는 `?? 7` 이라 코스를 안 고르고
  ///   레이더를 켜면 가평에서도 "7번 국도"라고 말했다 (2026-09-04).
  ///   `routeId: 0` 은 trip_log 의 '모름' 값이다 (옛 기록에 남아 있을 수 있다).
  int? get _routeNo {
    final id =
        ref.watch(startedJourneyProvider)?.routeId ??
        ref.watch(tripLogProvider).active?.currentRouteId;
    return (id == null || id == 0) ? null : id;
  }

  /// ⓪ 레이더 탭인데 길을 안 골랐을 때 (SCREENS.md DR-01 진입).
  ///
  /// ⚠ **그림만 돈다.** 스윕은 장식이다 — 위치도 서버도 건드리지 않는다 (driveProvider 는 멈춰 있다).
  ///   전에는 멈춘 원을 그렸는데 화면이 죽어 보였다 (2026-09-09). 돌려 두되 블립은 없다 —
  ///   없는 발견을 찍으면 그때부터 거짓말이다.
  /// ⚠ 버튼 하나가 발견 탭으로 보낸다. 눌러도 아무 일 없는 화면을 남기지 않는다.
  Widget _idle() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 220, height: 220, child: RadarView(blips: [])),
          const SizedBox(height: AppSpace.x6),
          const Text(
            S.radarIdleTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.darkInk,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            S.radarIdleSub,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.darkInk2),
          ),
          const SizedBox(height: AppSpace.x5),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.routeBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              onPressed: () => context.go('/'),
              child: const Text(
                S.radarIdleCta,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// 시트를 안 고르고 내렸을 때의 하단. 레이더는 아직 안 돈다 — 이 버튼이 유일한 길이다.
  Widget _handoffButton() {
    final journey = ref.read(startedJourneyProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SizedBox(
        height: 50,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.routeBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          ),
          onPressed: journey == null || journey.path.length < 2
              ? null
              : () => _openHandoff(journey),
          child: const Text(
            S.radarHandoffAgain,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 12, 0),
      child: Row(
        children: [
          // 노선을 모르면 뱃지를 비운다. 번호를 지어내면 거짓말이 된다.
          if (_routeNo != null) ...[
            // 뱃지를 누르면 「길을 바꿀까요?」 (DR-08). 달리는 중일 때만.
            Semantics(
              button: _armed,
              label: S.switchTitle,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _armed ? _openRouteSwitch : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: RouteBadge('$_routeNo', size: BadgeSize.sm),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          const Expanded(
            child: Text(
              S.radarScanning,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.darkInk2,
              ),
            ),
          ),
          // ⚠ 🔔(DR-06a)은 없앴다 (2026-09-08). 권한은 출발할 때 한 번 묻는다.
          IconButton(
            icon: Icon(
              _voiceOn ? Icons.volume_up_outlined : Icons.volume_off_outlined,
              color: AppColors.darkInk2,
              size: 20,
            ),
            onPressed: () {
              setState(() => _voiceOn = !_voiceOn);
              if (!_voiceOn) ref.read(voiceProvider).stop();
            },
          ),
        ],
      ),
    );
  }

  /// 레이더에 아무것도 없을 때의 한 줄.
  ///
  /// 반경 30km에 스팟이 하나도 없으면 **아직 안 모은 지역**이고,
  /// 있는데 안 잡히면 **지금 조용한** 것이다. 둘은 다른 말을 해야 한다.
  Widget _emptyNote() {
    final drive = ref.watch(driveProvider);
    if (!drive.hasFix) return const SizedBox.shrink();

    final covered = ref.watch(coverageProvider(coverageKey(drive.lat!, drive.lng!)));
    // 아직 모르는 동안은 아무 말도 하지 않는다. 섣불리 '준비 중'이라 하면 거짓말이 된다.
    final hasData = covered.value;
    if (hasData == null) return const SizedBox.shrink();

    return IgnorePointer(
      // ⚠ 정가운데는 **내 위치 점 자리**다. 거기 두면 글자가 점에 겹쳐 읽히지 않는다.
      //   점 아래로 살짝 내린다.
      child: Align(
        alignment: const Alignment(0, 0.42),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasData ? S.radarQuiet : S.radarNotYet,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkInk,
                ),
              ),
              if (!hasData) ...[
                const SizedBox(height: 6),
                Text(
                  S.radarNotYetSub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.darkInk2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _radar(List<Discovery> queue) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.hero),
          border: Border.all(color: const Color(0x1AF0EDE6)),
          gradient: const RadialGradient(
            colors: [Color(0xFF241F19), Color(0xFF141110)],
            radius: 0.9,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              // ⚠ 30개를 다 찍으면 라벨이 서로 덮여 아무것도 못 읽는다.
              //   운전 중 화면이다 — **지금 앞에 있는 것 여덟 개**만 남긴다.
              //   레이더는 목록이 아니라 "주변을 살피는 중"이라는 시각화다.
              child: RadarView(blips: _aheadSpots(queue)),
            ),
            // 아무것도 안 잡힐 때. 원만 도는 화면은 고장으로 읽힌다.
            // ⚠ '아직 안 모은 지역'과 '지금 조용한 것'을 반드시 가른다 —
            //   데이터가 다 찬 길에서 '준비 중'이 뜨면 앱이 미완성으로 보인다.
            if (queue.isEmpty) Positioned.fill(child: _emptyNote()),
            // 기록 칩 — 붉은 점
            Positioned(
              top: 12,
              left: 14,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5484D),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    // ⚠ 숫자를 지어내지 않는다. 모의 주행이든 실주행이든 실제 누적 거리다.
                    // 노선을 모르면 번호 없이 거리만 말한다.
                    _routeNo == null
                        ? S.radarRecordingNoRoute(ref.watch(driveProvider).distanceKm.round())
                        : S.radarRecording(
                            '$_routeNo번 국도',
                            ref.watch(driveProvider).distanceKm.round(),
                          ),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkInk2,
                    ),
                  ),
                ],
              ),
            ),
            // ⚠ 우상단 「남은 Nkm」 칩은 지웠다 (2026-09-09). 오두막 아이콘·보라색은 거점(폐기)의
            //   흔적이었고, 숫자도 '고른 선형의 남은 길이'라 목적지가 없는 이 화면과 맞지 않았다 —
            //   국도 출발이면 그 선형은 120km 창(route_path_ahead)이라 사용자에게 뜻이 없다.
          ],
        ),
      ),
    );
  }

  Widget _notRouteNotice() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Text(
        S.radarNotRoute,
        style: TextStyle(fontSize: 13, height: 1.7, color: AppColors.darkInk2),
      ),
    );
  }

  /// 진단 한 줄 (DEMO_BUILD 빌드만). 후보 수 · 이번 여정에 알린 수 · 다음 카드까지 남은 간격 · 정차 초.
  /// ⚠ 출시 빌드엔 없다 — 줄어드는 숫자는 카운트다운이라(원칙 6) 사용자에게 보여줄 것이 아니다.
  Widget _diagLine(List<Discovery> queue, DriveState drive) {
    final fresh = queue.where((d) => !_shown.contains(d.spot.id)).length;
    final (dk, ds) = _gap.remaining(drivenKm: drive.distanceKm, elapsedSec: drive.elapsedSec);
    final gap = dk <= 0 || ds <= 0 ? '간격 OK' : '간격 ${dk.toStringAsFixed(1)}km/${ds.round()}s';
    final text =
        'DIAG 후보 ${queue.length}(새 $fresh) · 알린 ${_shown.length} · $gap · '
        '정차 ${drive.stoppedSec.round()}s · 카드 ${_cardVisible ? "표시" : "없음"}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, height: 1.5, color: AppColors.darkInk3),
      ),
    );
  }

  Widget _finishButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: _FinishButton(onPressed: _finish),
    );
  }

  /// 오늘 여행을 마친다 → 여행기로. 버튼 하나가 하는 일의 전부다.
  void _finish() {
    // ⚠ 하드코딩된 'ep3'로 가고 있었다. 지금 막 끝낸 여행으로 간다.
    ref.read(driveProvider.notifier).stop();
    // ⚠ 마치면 **말도 멈춘다** (2026-09-09). 예약된 카드·낭독이 여행이 끝난 뒤에 나가면
    //   "혼자서 TTS 가 나왔다"가 된다. 타이머와 낭독 줄을 비운다.
    _nextCard?.cancel();
    _noAnswer?.cancel();
    ref.read(voiceProvider).stop();
    _current = null;
    _currentKm = null;
    _cardVisible = false;
    final log = ref.read(tripLogProvider.notifier);
    final id = log.end();
    // 51선 수집은 **지나온 점을 노선에 붙여** 센다 (맵매칭).
    // ⚠ 화면을 붙잡지 않는다. 실패해도 여행기는 열린다 — 그때는 예전 방식으로 센다.
    if (id != null) {
      final pts = log.pointsOf(id);
      ref
          .read(discoverRepositoryProvider)
          .matchRouteKm(pts)
          .then((byRoute) => log.setRouteKm(id, byRoute))
          .catchError((_) {});
    }
    // 여정을 비운다 → 레이더 탭은 다시 ⓪(길을 골라주세요)이 된다.
    ref.read(startedJourneyProvider.notifier).set(null);
    context.go(id == null ? '/my' : '/my/trip/$id');
  }
}

/// 「오늘 여행 마치기」 — 레이더의 유일한 하단 버튼 (2026-09-09 디자인 개정).
///
/// 어두운 화면에서 **밝은 크림 한 덩어리**로 선다. 전에는 얇은 외곽선(ghost)이라
/// 운전 중엔 눈에 안 들어왔고, 문구에 '→ 여행기 만들기'까지 붙어 두 가지를 말했다.
/// - 56pt: 운전 중 터치 영역 (CLAUDE.md 서체·터치 기준)
/// - 눌리는 동안 살짝 줄어들고(0.97) 짧은 진동 — 여행 하나를 닫는 손맛
/// - 아이콘은 책 한 권: 마치면 여행기가 된다는 걸 문구 대신 조용히 말한다
class _FinishButton extends StatefulWidget {
  const _FinishButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_FinishButton> createState() => _FinishButtonState();
}

class _FinishButtonState extends State<_FinishButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.radarFinish,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            height: 56,
            decoration: BoxDecoration(
              color: _down ? const Color(0xFFDDD9D0) : AppColors.darkInk,
              borderRadius: BorderRadius.circular(AppRadius.button),
              boxShadow: const [
                // 숯 위의 크림은 그림자가 아니라 **빛**으로 뜬다.
                BoxShadow(color: Color(0x2EF0EDE6), blurRadius: 28, offset: Offset(0, 6)),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories_outlined, size: 20, color: AppColors.darkBg),
                SizedBox(width: 9),
                Text(
                  S.radarFinish,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppColors.darkBg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// DR-02 근접 발견 카드 — 전면 카드 (SCREENS.md DR-02).
class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.discovery,
    required this.situation,
    required this.liked,
    required this.onVisit,
    required this.onSave,
    required this.onSkip,
  });

  final Discovery discovery;

  /// 상황 칩 한 줄. 앞머리 + 카드가 뜬 순간의 거리 — 레이더가 만들어 넘긴다 (S.cardSituation).
  final String situation;

  /// 찜 상태. 하트가 채워진다 — 카드가 남아 있으니 상태가 보여야 한다.
  final bool liked;
  final VoidCallback onVisit;
  final VoidCallback onSave;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final d = discovery;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SpotImage(type: d.spot.type, spotId: d.spot.id, imageUrl: d.spot.imageUrl, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x9E12100D),
                    Color(0x0012100D),
                    Color(0x0012100D),
                    Color(0xE612100D),
                  ],
                  stops: [0, 0.22, 0.40, 0.82],
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 132,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xF5FFFFFF),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 시의성을 색으로 먼저 알린다
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (d.spot.timeliness) {
                              Timeliness.marketDay => AppColors.marketRed,
                              Timeliness.sunset => AppColors.fieldGreen,
                              Timeliness.mealtime => AppColors.sun,
                              _ => AppColors.routeBlue,
                            },
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          situation,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF15100B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  // ⚠ 존재형 문구. 거리 카운트다운 금지.
                  Text(d.headline, style: AppType.drive.copyWith(color: Colors.white)),
                  const SizedBox(height: 11),
                  Text(d.body, style: AppType.driveBody.copyWith(color: const Color(0xE0FFFFFF))),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      Icon(Icons.verified_outlined, size: 15, color: Color(0xFF8FD3A4)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          S.cardVerified,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xCCFFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 원형 액션 3개 — 주 82pt / 보조 60pt
            Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _circle(Icons.close, AppTouch.driveSecondary, onSkip, muted: true),
                  const SizedBox(width: 20),
                  _primary(onVisit),
                  const SizedBox(width: 20),
                  _circle(
                    liked ? Icons.favorite : Icons.favorite_border,
                    AppTouch.driveSecondary,
                    onSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(IconData icon, double size, VoidCallback onTap, {bool muted = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x24FFFFFF),
          border: Border.all(color: const Color(0x57FFFFFF), width: 1.5),
        ),
        child: Icon(icon, size: 26, color: muted ? const Color(0xCCFFFFFF) : Colors.white),
      ),
    );
  }

  Widget _primary(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppTouch.drivePrimary,
        height: AppTouch.drivePrimary,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.near_me, size: 26, color: Color(0xFF12100D)),
            Text(
              S.cardVisit,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF12100D)),
            ),
          ],
        ),
      ),
    );
  }
}

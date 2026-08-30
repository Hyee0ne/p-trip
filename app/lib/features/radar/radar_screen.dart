import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/base_camp.dart';
import '../../core/drive.dart';
import '../../core/demo.dart';
import '../../core/env.dart';
import '../../core/journey.dart';
import '../../core/saves.dart';
import '../../core/proximity_alert.dart';
import '../../core/settings.dart';
import '../../core/strings.dart';
import '../../core/sunset.dart';
import '../../core/theme.dart';
import '../../core/trip_log.dart';
import '../../core/voice.dart';
import 'catchup_sheet.dart';
import 'passenger_mode.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../handoff/handoff_sheet.dart';
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
  SpotType? _lastType;

  /// 카드를 내보낸 주행 시각(분). 30분당 2회 상한을 재는 데 쓴다.
  final _shownAtMin = <double>[];

  /// 오늘 이 자리의 해·달. 일몰 가중치가 쓴다.
  TodaySky? _sky;

  /// DR-05 동승자 모드. 켜면 레이더 뷰가 카드 덱으로 바뀐다.
  bool _passengerMode = Env.radarPassenger;

  /// 동승자가 고른 다음 정차지 후보.
  final _picked = <Spot>[];

  /// 정차 시 몰아보기(DR-03)를 띄우기 위한 스쳐간 목록
  final _passed = <Discovery>[];

  /// 지금 화면에 떠 있는 발견.
  Discovery? _current;

  /// 데모 코스(동해 바닷길). 실주행에서는 사용자가 고른 코스가 들어온다.
  static const _demoCourseId = kDemoCourseId;

  /// 카드를 띄우는 구간 — 진출로까지 3~7분 (TECH_SPEC §3.1 5번).
  /// 너무 이르면 잊어버리고, 너무 늦으면 상의할 시간이 없다.
  static const _minAhead = 3.0;
  static const _maxAhead = 7.0;

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
    _setRunning(TickerMode.valuesOf(context).enabled);
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

  void _setRunning(bool run) {
    if (!run) {
      ref.read(driveProvider.notifier).stop();
      return;
    }
    if (_started) return;
    _started = true;
    // ⚠ 모의 주행도 **실제 선형**을 따라간다. 좌표를 지어내지 않는다.
    //   데모 모드를 끄면 같은 선형 위를 진짜 GPS로 달린다 (마이 탭 설정).
    final demo = ref.read(demoModeProvider);
    final journey = ref.read(startedJourneyProvider);

    if (journey != null && journey.path.length >= 2) {
      _begin(journey.path, demo);
      ref
          .read(tripLogProvider.notifier)
          .start(
            routeId: journey.routeId,
            routeName: journey.routeName,
            startName: journey.startName,
            endName: journey.endName,
            courseId: journey.courseId,
          );
      return;
    }

    // 아무것도 안 고르고 레이더 탭을 바로 누른 사람 — 데모 코스가 돈다.
    ref.read(courseGeometryProvider(_demoCourseId).future).then((path) {
      if (!mounted || path.length < 2) return;
      _begin(path, demo);
      ref.read(courseProvider(_demoCourseId).future).then((course) {
        if (!mounted) return;
        ref
            .read(tripLogProvider.notifier)
            .start(
              routeId: course?.routeId ?? 7,
              routeName: course?.title ?? '동해 바닷길',
              startName: course?.startName ?? '삼척',
              endName: course?.endName ?? '강릉',
              courseId: _demoCourseId,
            );
      });
    });
  }

  /// 모의 주행이냐 실주행이냐만 가른다. 선형은 이미 정해져 온다.
  void _begin(List<GeoPoint> path, bool demo) {
    if (demo) {
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
    if (!_cooldownOk(drive)) return;

    Discovery? best;
    var bestScore = 0.0;
    final now = DateTime.now();
    for (final raw in queue) {
      final f = raw.spot.exitFrac;
      if (f == null || _shown.contains(raw.spot.id)) continue;
      final min = drive.minutesTo(f);
      if (min < _minAhead || min > _maxAhead) continue;
      // 같은 유형을 연속으로 내보내지 않는다 (§3.1 6번). 밥집 다음에 또 밥집은 지겹다.
      if (raw.spot.type == _lastType) continue;
      // ⚠ **여기서 일몰을 덧입힌다** (core/sunset.dart). 저장소는 하늘을 모른다.
      //   이걸 빼면 실데이터에서 Timeliness.sunset이 한 번도 안 붙어
      //   DR-02 일몰 카드도, DR-06 일몰 알림도 영영 안 나온다.
      final d = applySunset(raw, _sky, now);
      final score = _score(d.spot);
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    if (best == null) return;

    _shown.add(best.spot.id);
    _lastType = best.spot.type;
    _shownAtMin.add(_driveMinutes(drive));

    // DR-06 — 앱이 뒤에 있으면 카드 대신 **음성 + 알림**으로 나간다 (2026-08-29 결정).
    // ⚠ 시의성 없는 스팟은 ProximityAlerts가 알아서 거른다. 꺼둔 앱이 말을 걸 이유는 '오늘만' 뿐이다.
    // ⚠ 조건은 화면 안 쿨다운보다 엄격한 그대로 쓴다 — 음성이라고 자주 말하지 않는다.
    if (_background) {
      if (best.spot.timeliness != Timeliness.none) {
        // 운전 중엔 배너를 읽을 수 없다. 소리가 본 채널이고 알림은 나중에 볼 흔적이다.
        if (_voiceOn) ref.read(voiceProvider).speak('${best.headline}. ${best.situation}');
        // 뒤에서 알린 건 '보여줬다'가 아니다 — 응답할 화면이 없으니 스쳐간 발견으로 적립한다.
        ref.read(savesProvider.notifier).markPassed(best.spot.id);
        ref.read(tripLogProvider.notifier).addStop(best.spot, StopKind.passed);
        _passed.add(best);
      }
      ref
          .read(proximityAlertsProvider)
          .notify(spot: best.spot, head: best.headline, title: best.spot.name);
      return;
    }

    _current = best;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _cardVisible = true);
      _announce(best!);
    });
  }

  /// 주행 시간(분). 배속을 곱해 **실제 달린 시간**으로 환산한다 —
  /// 쿨다운은 시연 배속이 아니라 여정을 기준으로 걸려야 한다.
  double _driveMinutes(DriveState drive) => drive.elapsedSec * Env.driveScale / 60;

  /// 30분당 최대 2회 (§3.1 6번). 재촉하지 않는 게 이 앱의 태도다.
  bool _cooldownOk(DriveState drive) {
    final now = _driveMinutes(drive);
    _shownAtMin.removeWhere((t) => now - t > 30);
    return _shownAtMin.length < 2;
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

  /// 0.1도 격자로 반올림. sun_moon 캐시가 그 단위다.
  static double _grid(double v) => (v * 10).roundToDouble() / 10;

  /// GPS 로그와 주행 거리를 여행 기록에 남긴다.
  /// ⚠ 매 프레임 쓰지 않는다 — 0.5km마다 한 점이면 여행기를 그리기에 충분하다.
  double _lastLoggedKm = -1;

  /// 마지막으로 점을 찍은 **실시간**. 정차 구간을 경로에 남기는 기준이다.
  DateTime _lastLoggedAt = DateTime.now();

  /// 몰아보기를 이미 띄웠는지. 한 번 멈출 때 한 번만 띄운다.
  bool _catchupShown = false;

  /// 정차 3분이면 아까 스쳐간 것들을 모아 보여준다 (SCREENS DR-03).
  /// ⚠ 주행 시간 기준이다 — 시연 배속과 무관하게 '3분 멈춤'이어야 한다.
  /// 40분간 이동이 없으면 레이더를 접는다 (SCREENS.md DR-06).
  /// ⚠ 무음 알림 한 번. 접었다는 사실만 남기고 아무것도 재촉하지 않는다.
  bool _folded = false;

  void _maybeFold(DriveState drive) {
    if (_folded || !_background) return;
    if (drive.stoppedSec < ProximityAlerts.foldAfter.inSeconds) return;
    _folded = true;
    ref.read(proximityAlertsProvider).foldUp(S.bgStopped);
    ref.read(driveProvider.notifier).stop();
  }

  void _maybeCatchup(DriveState drive) {
    if (drive.running) {
      _catchupShown = false;
      return;
    }
    if (_catchupShown || _cardVisible || _passed.length < 2) return;
    if (drive.stoppedSec * Env.driveScale / 60 < 3) return;
    _catchupShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CatchupSheet.show(
        context,
        passed: [..._passed],
        onDone: (remaining) {
          _passed
            ..clear()
            ..addAll(remaining);
          // 시트를 닫으면 다시 달린다. 멈춘 채로 두면 시연이 거기서 끝난다.
          if (mounted) ref.read(driveProvider.notifier).resume();
        },
      );
    });
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
      ref.read(voiceProvider).speak('${d.headline}. ${d.situation}');
    }
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

    final log = ref.read(tripLogProvider.notifier);
    if (saved) {
      log.addStop(current.spot, StopKind.visited);
    } else {
      // ✕ / 무시 → 스쳐간 발견으로 조용히 적립 (재촉 금지 원칙)
      ref.read(savesProvider.notifier).markPassed(current.spot.id);
      log.addStop(current.spot, StopKind.passed);
      _passed.add(current);
      showAppToast(context, S.toastPassed);
    }
    setState(() {
      _cardVisible = false;
      _current = null;
    });
    // 카드가 사라지고 바로 다음 걸 띄우지 않는다. 다음 발견이 앞에 올 때까지 기다린다.
    _nextCard?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(radarQueueProvider);
    final base = ref.watch(baseCampProvider);
    final drive = ref.watch(driveProvider);
    // 일몰 가중치용. 격자 단위라 위치가 조금 움직여도 같은 값을 재사용한다.
    if (drive.hasFix) {
      _sky = ref.watch(todaySkyProvider((lat: _grid(drive.lat!), lng: _grid(drive.lng!)))).value;
    }
    // ⚠ build 안에서 provider를 고치면 안 된다 (Riverpod). 주행이 바뀔 때만 반응한다.
    ref.listen(driveProvider, (_, next) {
      _record(next);
      _maybeFold(next);
      _maybeCatchup(next);
      _pickAhead(next, ref.read(radarQueueProvider).value ?? const []);
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
              if (_passengerMode) {
                return PassengerMode(
                  lat: drive.lat ?? 37.5245,
                  lng: drive.lng ?? 129.1143,
                  headingDeg: drive.headingDeg,
                  picked: _picked,
                  onExit: () => setState(() => _passengerMode = false),
                  onPick: (s) => setState(() {
                    if (!_picked.any((p) => p.id == s.id)) _picked.add(s);
                  }),
                );
              }
              // DR-00 — 실주행인데 위치를 못 받는다. 레이더는 위치가 전부라
              // 빈 화면을 보여주느니 이유를 말하고 길을 둘 다 열어둔다.
              if (drive.needsLocation) return _needsLocation();
              final current = _current;
              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      _topBar(),
                      _baseChip(base),
                      const SizedBox(height: AppSpace.x4),
                      _radar(queue),
                      const SizedBox(height: AppSpace.x5),
                      _notRouteNotice(),
                      const SizedBox(height: AppSpace.x4),
                      _soloLine(),
                      const SizedBox(height: AppSpace.x5),
                      _finishButton(),
                    ],
                  ),
                  if (_cardVisible && current != null)
                    _DiscoveryCard(
                      discovery: current,
                      onVisit: () {
                        // 거점이 있으면 **거점을 목적지로 두고 이 발견을 경유지로** 넘긴다.
                        // 그전엔 목적지를 발견으로 바꿔서 오늘 밤 잘 곳이 사라졌다.
                        final p = HandoffSheet.visitParams(
                          spot: HandoffPlace(current.spot.name, current.spot.lat, current.spot.lng),
                          base: ref.read(baseCampProvider),
                          driving: true,
                        );
                        HandoffSheet.show(
                          context,
                          mode: HandoffMode.visit,
                          destination: p.destination,
                          via: p.via,
                        );
                        // 들르러 갔으니 잠깐 멈춘다. 정차가 DR-03 몰아보기의 조건이다.
                        ref.read(driveProvider.notifier).pause();
                        _advance(saved: true);
                      },
                      onSave: () {
                        ref.read(savesProvider.notifier).toggleLike(SaveRef.spot(current.spot.id));
                        showAppToast(context, S.toastSaved);
                        _advance(saved: true);
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

  /// 지금 달리는 노선 번호. 기록 중인 여행에서 가져온다 —
  /// 화면에 7을 박아두면 어느 길을 달려도 7번 국도라고 말하게 된다.
  int get _routeNo => ref.watch(tripLogProvider).active?.routeId ?? 7;

  /// DR-06a 유도 화면. **조건부 1회** — 여기가 유일하게 권한을 묻는 자리다.
  Future<void> _askBackground() async {
    final yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x6, AppSpace.gutter, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              S.bgOptInTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.darkInk,
              ),
            ),
            const SizedBox(height: AppSpace.x2),
            const Text(
              S.bgOptInSub,
              style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.darkInk2),
            ),
            const SizedBox(height: AppSpace.x5),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppTouch.min,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.darkLine),
                        foregroundColor: AppColors.darkInk2,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text(S.bgOptInNo),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: SizedBox(
                    height: AppTouch.min,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.routeBlue),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text(S.bgOptInYes),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (yes != true) return;
    // ⚠ 권한을 거절하면 켜지 않는다. 켠 줄 알고 기다리게 두지 않는다.
    final ok = await ref.read(proximityAlertsProvider).requestPermission();
    await ref.read(backgroundAlertsProvider.notifier).set(ok);
    // ⚠ 이미 달리는 중이면 스트림을 다시 연다. 안 그러면 이번 주행 내내
    //   백그라운드 위치가 꺼진 채라 알림이 한 건도 안 나간다.
    if (ok && mounted && !ref.read(demoModeProvider)) {
      _started = false;
      _setRunning(true);
    }
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 12, 0),
      child: Row(
        children: [
          RouteBadge('$_routeNo', size: BadgeSize.sm),
          const SizedBox(width: 10),
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
          // DR-06a — 여행을 2번 이상 마친 사람에게만, 이미 켰으면 안 보인다.
          // ⚠ 온보딩·첫 진입에서는 절대 묻지 않는다 (권한 피로 = 이탈).
          if (ref.watch(tripsProvider).value != null &&
              ref.watch(tripsProvider).value!.length >= 2 &&
              !ref.watch(backgroundAlertsProvider))
            IconButton(
              icon: const Icon(Icons.notifications_none, color: AppColors.darkInk2, size: 20),
              onPressed: _askBackground,
            ),
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
          IconButton(
            icon: Icon(
              _passengerMode ? Icons.people : Icons.people_outline,
              color: _passengerMode ? AppColors.routeBlue : AppColors.darkInk2,
              size: 20,
            ),
            // ⚠ 모드를 바꿔도 주행·기록은 그대로 돈다 (SCREENS.md DR-05).
            onPressed: () => setState(() => _passengerMode = !_passengerMode),
          ),
        ],
      ),
    );
  }

  /// ⚠ **탭하면 거점을 정하러 간다.** CO-08에서 거점을 빼면서(2026-08-30)
  ///   거점 진입로가 코스뿐이 됐다 — 주 흐름에서 닿을 데가 없어진다.
  ///   잘 곳은 가면서 정하는 게 이 앱의 결에도 맞다.
  /// ⚠ 거점이 없으면 「들르기」가 목적지를 발견으로 바꿔버려 경유지가 안 걸린다.
  Widget _baseChip(BaseCamp? base) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GestureDetector(
        onTap: () => context.push('/base'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0x14F0EDE6),
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: AppColors.darkLine),
          ),
          child: Row(
            children: [
              const Icon(Icons.cabin_outlined, size: 15, color: Color(0xFFB79BE0)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  base == null ? S.baseChipNone : S.baseChipSet(base.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.darkInk2),
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.darkInk2),
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
                    S.radarRecording('$_routeNo번 국도', ref.watch(driveProvider).distanceKm.round()),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkInk2,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 14,
              child: Row(
                children: [
                  const Icon(Icons.cabin_outlined, size: 12, color: Color(0xFFB79BE0)),
                  const SizedBox(width: 5),
                  Text(
                    // ⚠ 거점까지 거리는 아직 계산하지 않는다. 18km는 지어낸 값이었다.
                    //   코스 진행률로 남은 거리는 알 수 있으니 그걸 말한다.
                    '남은 ${(ref.watch(driveProvider).courseKm - ref.watch(driveProvider).distanceKm).toStringAsFixed(0)}km',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB79BE0),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _soloLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x0FF0EDE6),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.darkLine),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.mic_none, size: 15, color: Color(0xFF93A6B6)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                S.radarSolo,
                style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.darkInk2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _finishButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SizedBox(
        height: 50,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkInk,
            backgroundColor: const Color(0x17F0EDE6),
            side: const BorderSide(color: AppColors.darkLine),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          ),
          onPressed: () {
            // ⚠ 하드코딩된 'ep3'로 가고 있었다. 지금 막 끝낸 여행으로 간다.
            ref.read(driveProvider.notifier).stop();
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
            context.go(id == null ? '/my' : '/my/trip/$id');
          },
          child: const Text(
            S.radarFinish,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
    required this.onVisit,
    required this.onSave,
    required this.onSkip,
  });

  final Discovery discovery;
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
                          d.situation,
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
                  _circle(Icons.favorite_border, AppTouch.driveSecondary, onSave),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/base_camp.dart';
import '../../core/drive.dart';
import '../../core/env.dart';
import '../../core/saves.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/trip_log.dart';
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

class _RadarScreenState extends ConsumerState<RadarScreen> {
  Timer? _nextCard;
  bool _cardVisible = false;
  bool _voiceOn = true;
  bool _started = false;

  /// 이미 내보낸 발견. 같은 카드를 두 번 띄우지 않는다.
  final _shown = <String>{};

  /// 정차 시 몰아보기(DR-03)를 띄우기 위한 스쳐간 목록
  final _passed = <Discovery>[];

  /// 지금 화면에 떠 있는 발견.
  Discovery? _current;

  /// 데모 코스(동해 바닷길). 실주행에서는 사용자가 고른 코스가 들어온다.
  static const _demoCourseId = '7d0e6a2c-0000-4000-8000-000000000007';

  /// 카드를 띄우는 구간 — 진출로까지 3~7분 (TECH_SPEC §3.1 5번).
  /// 너무 이르면 잊어버리고, 너무 늦으면 상의할 시간이 없다.
  static const _minAhead = 3.0;
  static const _maxAhead = 7.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠ 탭 셸이 IndexedStack이라 이 화면은 다른 탭에 있어도 살아 있다.
    //   TickerMode를 보고 실제로 보일 때만 주행을 돌린다.
    //   안 그러면 발견 탭에 있는 동안에도 GPS 로깅이 도는 셈이 된다.
    _setRunning(TickerMode.valuesOf(context).enabled);
  }

  void _setRunning(bool run) {
    if (!run) {
      ref.read(driveProvider.notifier).stop();
      return;
    }
    if (_started) return;
    _started = true;
    // ⚠ 모의 주행은 **실제 코스 선형**을 따라간다. 좌표를 지어내지 않는다.
    //   실주행으로 바꿀 땐 DriveNotifier만 geolocator 스트림으로 갈아끼우면 된다.
    ref.read(courseGeometryProvider(_demoCourseId).future).then((path) {
      if (!mounted || path.length < 2) return;
      ref.read(driveProvider.notifier).start(path);
      // 달리기 시작 = 여행 시작. 기기 안에 기록이 쌓인다 (core/trip_log.dart).
      ref
          .read(tripLogProvider.notifier)
          .start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    });
  }

  @override
  void dispose() {
    _nextCard?.cancel();
    super.dispose();
  }

  /// 진행률이 바뀔 때마다 **앞에 있는 발견**을 고른다.
  /// 시간으로 띄우지 않는다 — 어디를 지나고 있느냐가 기준이다.
  void _pickAhead(DriveState drive, List<Discovery> queue) {
    if (_cardVisible || _current != null || queue.isEmpty || !drive.running) return;
    if (!Env.autoCard) return;
    // 레이더를 먼저 보여준 뒤 발견이 다가온다. 바로 덮으면 레이더를 못 본다 (SCREENS DR-01).
    if (drive.elapsedSec < 4) return;

    for (final d in queue) {
      final f = d.spot.exitFrac;
      if (f == null || _shown.contains(d.spot.id)) continue;
      final min = drive.minutesTo(f);
      if (min < _minAhead || min > _maxAhead) continue;
      _shown.add(d.spot.id);
      _current = d;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _cardVisible = true);
      });
      return;
    }
  }

  /// GPS 로그와 주행 거리를 여행 기록에 남긴다.
  /// ⚠ 매 프레임 쓰지 않는다 — 0.5km마다 한 점이면 여행기를 그리기에 충분하다.
  double _lastLoggedKm = -1;

  void _record(DriveState drive) {
    if (!drive.running || !drive.hasFix) return;
    final log = ref.read(tripLogProvider.notifier);
    log.updateDistance(drive.distanceKm);
    if (drive.distanceKm - _lastLoggedKm < 0.5) return;
    _lastLoggedKm = drive.distanceKm;
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

  void _advance({required bool saved}) {
    final current = _current;
    if (current == null) return;

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
    _record(drive);
    _pickAhead(drive, queueAsync.value ?? const []);

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
                        HandoffSheet.show(
                          context,
                          mode: HandoffMode.visit,
                          destination: HandoffPlace(
                            current.spot.name,
                            current.spot.lat,
                            current.spot.lng,
                          ),
                        );
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

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 12, 0),
      child: Row(
        children: [
          const RouteBadge('7', size: BadgeSize.sm),
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
          IconButton(
            icon: Icon(
              _voiceOn ? Icons.volume_up_outlined : Icons.volume_off_outlined,
              color: AppColors.darkInk2,
              size: 20,
            ),
            onPressed: () => setState(() => _voiceOn = !_voiceOn),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline, color: AppColors.darkInk2, size: 20),
            onPressed: () => showAppToast(context, '동승자 모드는 준비 중이에요'),
          ),
        ],
      ),
    );
  }

  Widget _baseChip(BaseCamp? base) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
          ],
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
                    '7번 국도 ${ref.watch(driveProvider).distanceKm.toStringAsFixed(0)}km 기록 중',
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
            final id = ref.read(tripLogProvider.notifier).end();
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

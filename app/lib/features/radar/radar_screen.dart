import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/base_camp.dart';
import '../../core/env.dart';
import '../../core/saves.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
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
  // TODO(M3): geolocator 위치 스트림으로 교체. 지금은 데모 모드(mock 주행)만.
  Timer? _demo;
  Timer? _firstCard;
  Timer? _nextCard;
  int _queueIndex = 0;
  bool _cardVisible = false;
  double _recordedKm = 34;
  bool _voiceOn = true;

  /// 정차 시 몰아보기(DR-03)를 띄우기 위한 스쳐간 목록
  final _passed = <Discovery>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠ 탭 셸이 IndexedStack이라 이 화면은 다른 탭에 있어도 살아 있다.
    //   TickerMode를 보고 실제로 보일 때만 타이머를 돌린다.
    //   안 그러면 발견 탭에 있는 동안에도 GPS 로깅·폴링이 도는 셈이 된다.
    _setRunning(TickerMode.valuesOf(context).enabled);
  }

  void _setRunning(bool run) {
    if (run == (_demo != null)) return;
    if (!run) {
      _demo?.cancel();
      _demo = null;
      _firstCard?.cancel();
      _firstCard = null;
      return;
    }
    // 데모 모드: 8초마다 다음 발견이 다가온다
    _demo = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      setState(() {
        _recordedKm += 6;
        if (!_cardVisible) _cardVisible = true;
      });
    });
    if (!Env.autoCard) return;
    if (!_cardVisible) {
      // ⚠ Future.delayed는 취소가 안 돼 화면이 사라진 뒤에도 남는다. Timer로 잡아둔다.
      _firstCard?.cancel();
      // 레이더를 먼저 보여준 뒤 발견이 다가온다. 바로 덮으면 레이더를 못 본다.
      _firstCard = Timer(const Duration(milliseconds: 4200), () {
        if (mounted) setState(() => _cardVisible = true);
      });
    }
  }

  @override
  void dispose() {
    _demo?.cancel();
    _firstCard?.cancel();
    _nextCard?.cancel();
    super.dispose();
  }

  void _advance({required bool saved}) {
    final queue = ref.read(radarQueueProvider).value ?? const [];
    if (queue.isEmpty) return;
    final current = queue[_queueIndex % queue.length];

    if (!saved) {
      // ✕ / 무시 → 스쳐간 발견으로 조용히 적립 (재촉 금지 원칙)
      ref.read(savesProvider.notifier).markPassed(current.spot.id);
      _passed.add(current);
      showAppToast(context, S.toastPassed);
    }
    setState(() {
      _queueIndex++;
      _cardVisible = false;
    });
    _nextCard?.cancel();
    _nextCard = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _cardVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(radarQueueProvider);
    final base = ref.watch(baseCampProvider);

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
              final current = queue.isEmpty ? null : queue[_queueIndex % queue.length];
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
                          destinationName: current.spot.name,
                        );
                        _advance(saved: true);
                      },
                      onSave: () {
                        ref.read(savesProvider.notifier).toggleLike(current.spot.id);
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
              child: RadarView(blips: queue.map((d) => d.spot).toList()),
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
                    '7번 국도 ${_recordedKm.toStringAsFixed(0)}km 기록 중',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkInk2,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 12,
              right: 14,
              child: Row(
                children: [
                  Icon(Icons.cabin_outlined, size: 12, color: Color(0xFFB79BE0)),
                  SizedBox(width: 5),
                  Text(
                    '거점 18km',
                    style: TextStyle(
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
          onPressed: () => context.go('/my/trip/ep3'),
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
            SpotImage(type: d.spot.type, radius: 0),
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

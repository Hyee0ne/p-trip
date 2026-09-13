import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/journey.dart';
import '../../core/trip_log.dart';
import '../../core/nav.dart';
import '../../core/location.dart';
import '../../core/proximity_alert.dart';
import '../../core/settings.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/route_badge.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';

/// CO-08 길 떠나기 — 노선 탭 직후.
///
/// **길을 골랐으니 어느 쪽으로 갈지만 정하고 출발한다.** 코스를 거치지 않는다.
///
/// ⚠ 거리·소요시간·도착지를 묻지 않는다. 그건 내비의 질문이다 (원칙 1).
/// ⚠ 이 길에 발견이 몇 곳인지 **개수는 보여줘도 목록은 보여주지 않는다** —
///   안심의 근거이지 계획표가 아니다 (CO-01 재설계).
/// ⚠ 잘 곳을 묻지 않는다. 거점 개념 자체를 없앴다 (2026-09-07) — 이 앱은 숙소 앱이 아니다.
class DepartSheet extends ConsumerStatefulWidget {
  const DepartSheet({super.key, required this.route, this.note});

  final RouteLine route;
  final RouteNote? note;

  static Future<void> show(BuildContext context, RouteLine route, {RouteNote? note}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DepartSheet(route: route, note: note),
    );
  }

  @override
  ConsumerState<DepartSheet> createState() => _DepartSheetState();
}

class _DepartSheetState extends ConsumerState<DepartSheet> {
  bool _busy = false;
  String? _error;

  bool get _ew => widget.route.axis == 'EW';

  Future<void> _depart(bool northOrEast) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final fix = await ref.read(currentLocationProvider.future);
    if (!fix.hasFix) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = S.departNeedLocation;
        });
      }
      return;
    }

    final path = await ref
        .read(discoverRepositoryProvider)
        .routePathAhead(
          routeId: widget.route.id,
          lat: fix.lat!,
          lng: fix.lng!,
          northOrEast: northOrEast,
        );
    if (!mounted) return;

    // 이을 수 있는 선형이 없으면 출발시키지 않는다. 없는 길을 달리게 하지 않는다.
    if (path.length < 2) {
      setState(() {
        _busy = false;
        _error = S.departNoPath;
      });
      return;
    }

    // ⚠ 알림 권한은 **여기서 한 번** 묻는다 (SCREENS.md DR-01 진입, 2026-09-08).
    //   iOS 는 평생 한 번만 묻는다. 온보딩은 설명만 하고, 실제 팝업은 출발하는 이 순간이다 —
    //   "앱을 내려도 알려준다"가 무슨 뜻인지 가장 잘 아는 때다. 이미 물었으면 그냥 지나간다.
    //   허용이든 거절이든 출발을 막지 않는다.
    await ref
        .read(backgroundAlertsProvider.notifier)
        .askOnce(ref.read(proximityAlertsProvider).requestPermission);
    if (!mounted) return;

    ref
        .read(startedJourneyProvider.notifier)
        .set(
          Journey(
            routeId: widget.route.id,
            routeName: widget.route.name.isEmpty
                ? S.routeNumber(widget.route.id)
                : widget.route.name,
            path: path,
            // 여행 중이면 새 여행이 아니라 갈아타기다 (DR-08) — 거리·기록이 이어진다.
            continues: ref.read(tripLogProvider).active != null,
          ),
        );

    // ⚠ 내비로 보내지 않는다. 레이더가 먼저고, 핸드오프 시트는 **레이더 위에서** 뜬다 —
    //   전에는 여기서 바로 카카오내비로 넘겨서 사용자가 이 앱의 핵심 화면을 한 번도
    //   안 보고 떠났다 (2026-09-08).
    // ⚠ **발견 탭을 뿌리로 돌려놓고 간다** (2026-09-09). 전에는 시트를 둔 채 탭만 바꿨다 —
    //   이 시트는 발견 탭의 내비게이터 위에 떠 있어서, 여행을 마치고 발견 탭에 돌아오면
    //   `_busy`(버튼 비활성)인 채 그대로 남아 있었다. 실기기에서 잡았다.
    departToRadar(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    final title = r.name.isEmpty ? S.routeNumber(r.id) : r.name;
    // 여행 중이면 한 줄 — 갈아타도 기록이 이어진다고 말해 둔다 (DR-08).
    final activeRoute = ref.watch(tripLogProvider).active?.currentRouteId;
    final note = widget.note;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 12, AppSpace.gutter, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line2,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.x5),
          Row(
            children: [
              RouteBadge('${r.id}', size: BadgeSize.lg),
              const SizedBox(width: AppSpace.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.ink,
                      ),
                    ),
                    // 시의성이 있을 때만. 없으면 줄을 그리지 않는다.
                    if (note != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        switch (note.kind) {
                          RouteNoteKind.marketToday => S.routeNoteMarket(note.spots),
                          RouteNoteKind.rising => S.routeNoteRising,
                          RouteNoteKind.popular => S.routeNotePopular,
                        },
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: switch (note.kind) {
                            RouteNoteKind.marketToday => AppColors.marketRed,
                            RouteNoteKind.rising => AppColors.sun,
                            // 흔적은 변화보다 조용한 색으로. 같은 무게가 아니다.
                            RouteNoteKind.popular => AppColors.fieldGreen,
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.x5),
          const Text(S.departWhichWay, style: TextStyle(fontSize: 13.5, color: AppColors.ink2)),
          if (activeRoute != null && activeRoute != r.id) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.tintSun,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Text(
                S.departSwitchNote(activeRoute, r.id),
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onTintSun,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.x3),
          Row(
            children: [
              Expanded(child: _wayButton(true)),
              const SizedBox(width: AppSpace.x2),
              Expanded(child: _wayButton(false)),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.x3),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.marketRed),
            ),
          ],
          const SizedBox(height: AppSpace.x4),
          const Center(
            child: Text(
              S.departNoDestination,
              style: TextStyle(fontSize: 11.5, color: AppColors.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wayButton(bool northOrEast) {
    final label = _ew
        ? (northOrEast ? S.departEast : S.departWest)
        : (northOrEast ? S.departNorth : S.departSouth);
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.routeBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
        onPressed: _busy ? null : () => _depart(northOrEast),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

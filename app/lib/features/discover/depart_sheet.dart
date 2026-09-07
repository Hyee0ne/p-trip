import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/geo.dart';
import '../../core/journey.dart';
import '../../core/location.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/route_badge.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../handoff/handoff_sheet.dart';

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

/// 이보다 가까우면 이미 국도 위다 — 안내할 게 없다.
const _entryThresholdKm = 0.3;

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

    ref
        .read(startedJourneyProvider.notifier)
        .set(
          Journey(
            routeId: widget.route.id,
            routeName: widget.route.name.isEmpty
                ? S.routeNumber(widget.route.id)
                : widget.route.name,
            path: path,
          ),
        );

    // ⚠ **국도까지는 데려다줘야 한다.** 집에서 출발하면 국도 위에 있지도 않다.
    //   목적지는 **그 국도의 진입점**이다 — 선형의 끝을 목적지로 잡으면
    //   카카오내비가 최단 경로로 안내해서 **고속도로로 빠진다.** 국도를 타려고 켠 내비가
    //   국도를 벗어나게 만드는 셈이다. 짧게 끊어야 그 일이 안 생긴다.
    final entry = path.first;
    final toEntryKm = roughKm(fix.lat!, fix.lng!, entry.lat, entry.lng);
    if (toEntryKm > _entryThresholdKm) {
      await HandoffSheet.show(
        context,
        mode: HandoffMode.depart,
        destination: HandoffPlace(S.routeNumber(widget.route.id), entry.lat, entry.lng),
      );
      if (!mounted) return;
    }
    // 이미 국도 위면 안내할 게 없다. 바로 달린다.
    context.go('/radar');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    final title = r.name.isEmpty ? S.routeNumber(r.id) : r.name;
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

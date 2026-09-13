import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/route_badge.dart';
import '../../data/models/models.dart';

/// DR-08 「길을 바꿀까요?」 — 여행 중 다른 국도로 갈아타는 시트 (SCREENS.md DR-08, 2026-09-13).
///
/// 홈의 「여기서 탈 수 있는 길」과 같은 조회(현 위치 30km)를 쓴다. 지금 길은 「지금 이 길」로만 표시하고,
/// 나머지는 방향 버튼 둘 — 출발 시트(CO-08)와 같은 문법이다. 고르면 `(노선, 북·동인가)` 를 돌려준다.
/// ⚠ 갈아타라고 권하지 않는다 (원칙 6). 상단 뱃지를 누른 사람에게만 열린다.
class RouteSwitchSheet extends StatelessWidget {
  const RouteSwitchSheet({super.key, required this.currentRouteId, required this.result});

  final int currentRouteId;
  final NearbyResult result;

  static Future<(RouteLine, bool)?> show(
    BuildContext context, {
    required int currentRouteId,
    required NearbyResult result,
  }) => showModalBottomSheet<(RouteLine, bool)>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => RouteSwitchSheet(currentRouteId: currentRouteId, result: result),
  );

  @override
  Widget build(BuildContext context) {
    final routes = result.routes;
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(S.switchTitle, style: AppType.h2),
          const SizedBox(height: 4),
          const Text(S.switchSub, style: TextStyle(fontSize: 13, color: AppColors.ink2)),
          const SizedBox(height: 10),
          if (routes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(S.switchEmpty, style: TextStyle(fontSize: 13.5, color: AppColors.ink2)),
              ),
            )
          else
            for (var i = 0; i < routes.length; i++) ...[
              _RouteRow(n: routes[i], current: routes[i].route.id == currentRouteId),
              if (i != routes.length - 1)
                const Divider(height: 1, thickness: 1, color: AppColors.line),
            ],
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.n, required this.current});
  final NearbyRoute n;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final r = n.route;
    final ew = r.axis == 'EW';
    final name = r.name.isEmpty ? S.routeNumber(r.id) : r.name;
    final meta = [
      if (n.distanceKm != null) S.distanceLabel(n.distanceKm!),
      ew ? '동·서' : '남·북',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          RouteBadge('${r.id}', size: BadgeSize.sm),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppType.title.copyWith(fontSize: 14.5)),
                if (!current)
                  Text(meta, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
              ],
            ),
          ),
          if (current)
            const Text(
              S.switchCurrent,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.routeBlue,
              ),
            )
          else ...[
            _Dir(
              key: ValueKey('switch-${r.id}-a'),
              label: ew ? S.departEast : S.departNorth,
              onTap: () => Navigator.of(context).pop((r, true)),
            ),
            const SizedBox(width: 6),
            _Dir(
              key: ValueKey('switch-${r.id}-b'),
              label: ew ? S.departWest : S.departSouth,
              onTap: () => Navigator.of(context).pop((r, false)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dir extends StatelessWidget {
  const _Dir({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.routeBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    ),
  );
}

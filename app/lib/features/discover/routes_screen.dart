import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/route_badge.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';

/// CO-07 국도 선택 — 목적지가 아니라 '길'을 고르는 화면 (SCREENS.md CO-07).
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});
  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

enum _Axis { all, ns, ew }

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  _Axis _axis = _Axis.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(routesProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          S.routesTitle,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
        titleSpacing: 0,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, _) => const Center(child: Text(S.errNetwork)),
        data: (routes) {
          final list = switch (_axis) {
            _Axis.all => routes,
            _Axis.ns => routes.where((r) => r.axis == 'NS').toList(),
            _Axis.ew => routes.where((r) => r.axis == 'EW').toList(),
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.x8),
            children: [
              const Text(
                '${S.routesSub} · 총 14,000km',
                style: TextStyle(fontSize: 13.5, color: AppColors.ink2),
              ),
              const SizedBox(height: AppSpace.x4),
              _segments(),
              const SizedBox(height: AppSpace.x5),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 11,
                  crossAxisSpacing: 11,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (_, i) => _RouteTile(route: list[i]),
              ),
              const SizedBox(height: AppSpace.x6),
              Container(
                padding: const EdgeInsets.all(AppSpace.x4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FC),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Text(
                  S.onboard2,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.7,
                    color: Color(0xFF1A3E9E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segments() {
    Widget seg(String label, _Axis v) {
      final on = _axis == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _axis = v),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: on ? AppShadow.card : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                color: on ? AppColors.ink : AppColors.ink2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EDEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          seg('전체', _Axis.all),
          const SizedBox(width: 4),
          seg('남북(홀수)', _Axis.ns),
          const SizedBox(width: 4),
          seg('동서(짝수)', _Axis.ew),
        ],
      ),
    );
  }
}

class _RouteTile extends ConsumerWidget {
  const _RouteTile({required this.route});
  final RouteLine route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivable = route.drivable;
    return GestureDetector(
      onTap: drivable ? () => _openCourses(context, ref) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: drivable ? AppColors.surface : const Color(0xFFF0F4F5),
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: drivable ? AppShadow.card : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RouteBadge('${route.id}', size: BadgeSize.lg, drivable: drivable),
            const SizedBox(height: 9),
            Text(
              // 주행 불가 노선은 별명 대신 고정 문구를 쓴다 (SCREENS.md CO-07)
              drivable ? route.name : S.routeUndrivable,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: -0.3,
                color: drivable ? AppColors.ink : AppColors.ink2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              route.fromTo,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: AppColors.ink3),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCourses(BuildContext context, WidgetRef ref) async {
    final courses = await ref.read(coursesProvider(route.id).future);
    if (!context.mounted) return;
    if (courses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(S.routeNoCourse), duration: AppMotion.toast));
      return;
    }
    context.go('/course/${courses.first.id}');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/env.dart';
import '../../core/location.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/route_badge.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import 'route_map.dart';

/// CO-07 국도 선택 — 지도 전면 + 끌어올리는 바텀시트 (SCREENS.md CO-07).
///
/// 토글이 없다. **시트 높이가 곧 "내 주변 ↔ 51선 전체"다.**
/// 접으면 여기서 탈 수 있는 길, 끌어올리면 51선 전체 + 남북/동서.
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});
  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

enum _Axis { all, ns, ew }

/// 시트 3단. 화면 높이 대비 비율.
const _collapsed = 0.32;
const _mid = 0.58;
const _expanded = 0.92;

/// 이 위로 올라가면 '51선 전체' 모드로 읽는다.
const _expandedFrom = 0.45;

/// 시작 높이. `_extent` 초기값과 `initialChildSize`가 반드시 같아야 한다 —
/// 어긋나면 시트만 펼쳐지고 헤더는 접힘인 채로 남는다.
double get _initialExtent => Env.sheetExpanded ? _expanded : _collapsed;

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  final _sheet = DraggableScrollableController();
  _Axis _axis = _Axis.all;
  double _extent = _initialExtent;

  /// 위치를 못 받아 자동으로 펼친 적이 있는지 (한 번만 한다).
  bool _autoExpanded = false;

  bool get _isExpanded => _extent > _expandedFrom;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _animateTo(double size) {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(size, duration: AppMotion.base, curve: AppMotion.curve);
  }

  /// 위치가 없으면 시트를 펼쳐 51선을 보여준다 — 빈 화면으로 막지 않는다.
  void _autoExpandIfNoFix(LocFix fix) {
    if (_autoExpanded || fix.hasFix) return;
    _autoExpanded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animateTo(_expanded);
    });
  }

  Future<void> _askLocation(LocFix fix) async {
    switch (fix.status) {
      case LocStatus.serviceOff:
        await Geolocator.openLocationSettings();
      case LocStatus.deniedForever:
        await Geolocator.openAppSettings();
      case LocStatus.denied:
      case LocStatus.unavailable:
      case LocStatus.ready:
        ref.invalidate(currentLocationProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(routesProvider);
    final nearbyAsync = ref.watch(nearbyRoutesProvider);
    final fixAsync = ref.watch(currentLocationProvider);

    ref.listen(currentLocationProvider, (_, next) {
      final fix = next.value;
      if (fix != null) _autoExpandIfNoFix(fix);
    });

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
        // ⚠ 제목을 두지 않는다. 시트 헤더가 지금 보고 있는 걸 이미 말하고 있고
        //    ('여기서 탈 수 있는 길' / '국도 51선'), 겹쳐 쓰면 같은 말이 두 번 나온다.
        titleSpacing: 0,
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final routes = routesAsync.value ?? const <RouteLine>[];
          return Stack(
            children: [
              Positioned.fill(
                child: RouteMapPanel(
                  fix: fixAsync.value,
                  routes: routes,
                  bottomInset: _extent * box.maxHeight,
                ),
              ),
              NotificationListener<DraggableScrollableNotification>(
                onNotification: (n) {
                  if (n.extent != _extent) setState(() => _extent = n.extent);
                  return false;
                },
                child: DraggableScrollableSheet(
                  controller: _sheet,
                  initialChildSize: _initialExtent,
                  minChildSize: _collapsed,
                  maxChildSize: _expanded,
                  snap: true,
                  snapSizes: const [_mid],
                  builder: (context, scrollController) => _SheetSurface(
                    child: CustomScrollView(
                      key: const Key('routes-sheet-list'),
                      controller: scrollController,
                      slivers: _slivers(routesAsync, nearbyAsync, fixAsync),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _slivers(
    AsyncValue<List<RouteLine>> routesAsync,
    AsyncValue<List<NearbyRoute>> nearbyAsync,
    AsyncValue<LocFix> fixAsync,
  ) {
    bool matchesAxis(RouteLine r) => switch (_axis) {
      _Axis.all => true,
      _Axis.ns => r.axis == 'NS',
      _Axis.ew => r.axis == 'EW',
    };

    // 남북/동서 필터는 두 섹션에 똑같이 건다. 한쪽만 걸리면 목록이 서로 어긋난다.
    final nearby = (nearbyAsync.value ?? const <NearbyRoute>[])
        .where((n) => matchesAxis(n.route))
        .toList();
    final nearbyIds = nearby.map((n) => n.route.id).toSet();

    // '그 밖의 길'은 말 그대로 나머지다 — 내 주변에 이미 나온 노선을 또 싣지 않는다.
    final rest = (routesAsync.value ?? const <RouteLine>[])
        .where((r) => matchesAxis(r) && !nearbyIds.contains(r.id))
        .toList();

    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: _SheetHeader(
          scale: MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8),
          expanded: _isExpanded,
          nearbyCount: nearby.length,
          axis: _axis,
          onAxis: (a) => setState(() => _axis = a),
          onExpand: () => _animateTo(_expanded),
          onCollapse: () => _animateTo(_collapsed),
        ),
      ),

      // 내 주변 — 접힘 상태에서는 헤더가 이미 "여기서 탈 수 있는 길"이라 라벨을 빼둔다.
      if (_isExpanded && nearby.isNotEmpty) const _SectionLabel(S.routesSecNear),
      if (nearby.isEmpty)
        SliverToBoxAdapter(
          child: _NearbyState(fix: fixAsync, onAsk: _askLocation),
        )
      else
        SliverList.list(
          children: [for (final n in nearby) _RouteRow(route: n.route, distanceKm: n.distanceKm)],
        ),

      // 섹션이 하나뿐이면 라벨을 달지 않는다 — 나눌 게 없는데 나누는 시늉을 하지 않는다.
      if (nearby.isNotEmpty && rest.isNotEmpty) const _SectionLabel(S.routesSecAll),
      if (routesAsync.isLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.x8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        )
      else if (routesAsync.hasError)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.x8),
            child: Center(child: Text(S.errNetwork)),
          ),
        )
      else
        SliverList.list(children: [for (final r in rest) _RouteRow(route: r)]),

      SliverToBoxAdapter(
        child: SizedBox(height: AppSpace.x8 + MediaQuery.viewPaddingOf(context).bottom),
      ),
    ];
  }
}

/// 시트 표면 — 흰 배경 + 위쪽 라운드 + 떠 있는 그림자.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        boxShadow: AppShadow.float,
      ),
      child: child,
    );
  }
}

/// 시트 상단 고정 헤더. 접힘/펼침에 따라 내용이 바뀐다 — **토글이 아니라 상태다.**
class _SheetHeader extends SliverPersistentHeaderDelegate {
  _SheetHeader({
    required this.scale,
    required this.expanded,
    required this.nearbyCount,
    required this.axis,
    required this.onAxis,
    required this.onExpand,
    required this.onCollapse,
  });

  final bool expanded;
  final int nearbyCount;
  final _Axis axis;
  final ValueChanged<_Axis> onAxis;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;

  // 고정 높이 sliver라 내용이 넘치면 오버플로가 난다. 아래 TextStyle에 줄 높이를
  // 못박아 계산을 맞췄고, 시스템 글자 크기(textScaler)만큼 같이 키운다.
  // 접힘 = 8(top) + 4(handle) + 12 + 48(버튼 탭타깃) + 여유
  // 펼침 = 접힘 + 12 + 42(세그먼트) + 여유
  static const _base = 84.0;
  static const _withSegments = 142.0;

  /// 시스템 글자 크기 배율. 접근성 설정을 키워도 헤더가 안 터지게 한다.
  final double scale;

  @override
  double get minExtent => (expanded ? _withSegments : _base) * scale;
  @override
  double get maxExtent => minExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x2, AppSpace.x3, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: AppSpace.x3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: expanded
                      ? const [
                          Text(
                            S.routesTitle,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${S.routesSub} · 총 14,000km',
                            style: TextStyle(fontSize: 12.5, height: 1.3, color: AppColors.ink2),
                          ),
                        ]
                      : [
                          const Text(
                            S.routesNearTitle,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (nearbyCount > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              S.routesNearCount(nearbyCount),
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.3,
                                color: AppColors.ink2,
                              ),
                            ),
                          ],
                        ],
                ),
              ),
              if (expanded)
                IconButton(
                  onPressed: onCollapse,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                  color: AppColors.ink3,
                  tooltip: '접기',
                  // 기본 48이면 헤더 높이 계산이 어긋난다. 터치 최소값에 맞춘다.
                  constraints: const BoxConstraints.tightFor(
                    width: AppTouch.min,
                    height: AppTouch.min,
                  ),
                  padding: EdgeInsets.zero,
                )
              else
                TextButton(
                  onPressed: onExpand,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, AppTouch.min),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.x3),
                    foregroundColor: AppColors.routeBlue,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        S.routesAllCta,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_up, size: 18),
                    ],
                  ),
                ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: AppSpace.x3),
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.x2),
              child: _Segments(axis: axis, onAxis: onAxis),
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SheetHeader old) =>
      old.expanded != expanded ||
      old.nearbyCount != nearbyCount ||
      old.axis != axis ||
      old.scale != scale;
}

class _Segments extends StatelessWidget {
  const _Segments({required this.axis, required this.onAxis});
  final _Axis axis;
  final ValueChanged<_Axis> onAxis;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, _Axis v) {
      final on = axis == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => onAxis(v),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: on ? AppShadow.card : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.x5,
          AppSpace.gutter,
          AppSpace.x2,
        ),
        child: Text(
          text,
          // ⚠ 한글은 라틴처럼 자간을 벌리면 글자가 흩어져 보인다. 0.2까지만.
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: AppColors.ink3,
          ),
        ),
      ),
    );
  }
}

/// 내 주변이 비었을 때 — 위치 없음 / 측정 중 / 국도에서 멀리.
/// **막지 않는다.** 51선 목록은 아래에 그대로 있다.
class _NearbyState extends StatelessWidget {
  const _NearbyState({required this.fix, required this.onAsk});
  final AsyncValue<LocFix> fix;
  final Future<void> Function(LocFix) onAsk;

  @override
  Widget build(BuildContext context) {
    final value = fix.value;
    final loading = fix.isLoading;
    final askable = value?.askable ?? false;
    final unavailable = value?.status == LocStatus.unavailable;

    final text = loading
        ? S.routesLocFinding
        : (askable || unavailable ? S.routesLocOff : S.routesNearEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x2, AppSpace.gutter, 0),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink3),
            )
          else
            Icon(
              askable || unavailable ? Icons.location_off_outlined : Icons.explore_outlined,
              size: 18,
              color: AppColors.ink3,
            ),
          const SizedBox(width: AppSpace.x3),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.ink2),
            ),
          ),
          if (!loading && value != null && (askable || unavailable))
            TextButton(
              onPressed: () => onAsk(value),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppTouch.min),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.x3),
                foregroundColor: AppColors.routeBlue,
              ),
              child: const Text(
                S.routesLocCta,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// 노선 한 줄. 그리드 타일을 대체한다 — 뱃지가 커서 스캔이 되고, 보조설명이 한 줄 들어간다.
class _RouteRow extends ConsumerWidget {
  const _RouteRow({required this.route, this.distanceKm});

  final RouteLine route;

  /// 모르면 null — 거리를 지어내지 않는다.
  final double? distanceKm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivable = route.drivable;
    // 별명이 없으면 'N번 국도' — ⚠ 없는 이름을 지어내지 않는다.
    final title = drivable
        ? (route.name.isEmpty ? '${route.id}번 국도' : route.name)
        : S.routeUndrivable;
    final sub = distanceKm != null ? '${distanceKm!.round()}km' : route.fromTo;

    return InkWell(
      onTap: drivable ? () => _openCourses(context, ref) : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter, vertical: AppSpace.x2),
        child: Row(
          children: [
            RouteBadge('${route.id}', size: BadgeSize.lg, drivable: drivable),
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: drivable ? AppColors.ink : AppColors.ink2,
                    ),
                  ),
                  // 모르는 건 줄 자체를 그리지 않는다 (CO-03과 같은 규칙).
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
                    ),
                  ],
                ],
              ),
            ),
            if (drivable) const Icon(Icons.chevron_right, size: 20, color: AppColors.ink3),
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

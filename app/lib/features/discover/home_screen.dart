import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/view_mode.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/view_toggle.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import 'story_deck.dart';

/// CO-01 홈 — 뷰 모드 2개 (SCREENS.md CO-01).
///
/// A. 한 곳씩: 전면 카드 + 원형 액션 3개. 검색 아이콘을 두지 않는다.
/// B. 훑어보기: 검색창 + 필터 칩 한 줄 + 큐레이션 3축 그리드.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: mode == ViewMode.oneByOne ? const _OneByOne() : const _Browse(),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 4, AppSpace.gutter, 0),
      child: Row(
        children: [
          const RouteBadge('P', size: BadgeSize.md),
          const SizedBox(width: 9),
          Text(
            S.appName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
          const Spacer(),
          const ViewToggle(),
        ],
      ),
    );
  }
}

// ── A. 한 곳씩 ────────────────────────────────────────────────
class _OneByOne extends ConsumerWidget {
  const _OneByOne();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(curationDeckProvider);
    return Column(
      children: [
        const _Header(),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, _) => const _ErrorState(),
            data: (cards) => cards.isEmpty ? const _EmptyState() : StoryDeck(cards: cards),
          ),
        ),
      ],
    );
  }
}

// ── B. 훑어보기 ───────────────────────────────────────────────
class _Browse extends ConsumerStatefulWidget {
  const _Browse();
  @override
  ConsumerState<_Browse> createState() => _BrowseState();
}

class _BrowseState extends ConsumerState<_Browse> {
  bool _today = false;
  bool _near = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(),
        const SizedBox(height: 12),
        // 검색창 — 누르면 SR 검색 화면이 위로 덮인다
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: GestureDetector(
            onTap: () => context.push('/search'),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.line2),
              ),
              child: Row(
                children: const [
                  Icon(Icons.search, size: 16, color: AppColors.ink3),
                  SizedBox(width: 9),
                  Text(S.searchHint, style: TextStyle(fontSize: 14, color: AppColors.ink3)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 11),
        // 필터 — 한 줄. 밖에 두는 건 둘뿐.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Row(
            children: [
              DiscoverFilterChip(
                label: S.filterToday,
                selected: _today,
                onTap: () => setState(() => _today = !_today),
              ),
              const SizedBox(width: 7),
              DiscoverFilterChip(
                label: S.filterNear,
                selected: _near,
                onTap: () => setState(() => _near = !_near),
              ),
              const Spacer(),
              const FilterMoreChip(),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: const Key('browse-list'),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // 국도부터 고르기가 맨 위 — 목적지가 아니라 '길'을 고르는 게
              // 이 앱의 진입 문법이다 (기획문서 CO-07)
              const SizedBox(height: 22),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                child: SectionLabel(S.secRoutes),
              ),
              const SizedBox(height: 14),
              const _RouteRail(),
              _axisSection(CurationAxis.today, S.secToday),
              _axisSection(CurationAxis.rising, S.secRising),
              _axisSection(CurationAxis.tracks, S.secTracks),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  Widget _axisSection(CurationAxis axis, String title) {
    final async = ref.watch(axisSpotsProvider(axis));
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (spots) {
        var list = spots;
        if (_today) list = list.where((s) => s.timeliness != Timeliness.none).toList();
        if (_near) list = list.where((s) => s.detourMin <= 5).toList();

        // 변화율을 못 내는 축은 섹션을 통째로 숨긴다 (SCREENS.md CO-01 상태).
        if (list.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: SectionLabel(title),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 11,
                  crossAxisSpacing: 11,
                  childAspectRatio: 0.98,
                ),
                itemBuilder: (_, i) =>
                    SpotGridCard(spot: list[i], onTap: () => context.go('/spot/${list[i].id}')),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RouteRail extends ConsumerWidget {
  const _RouteRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(routesProvider);
    return SizedBox(
      height: 34,
      child: async.maybeWhen(
        orElse: () => const SizedBox.shrink(),
        data: (routes) {
          final drivable = routes.where((r) => r.drivable).take(4).toList();
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            children: [
              for (final r in drivable) ...[
                GestureDetector(
                  onTap: () => context.go('/routes'),
                  child: RouteBadge('${r.id}', size: BadgeSize.lg),
                ),
                const SizedBox(width: 12),
              ],
              GestureDetector(
                onTap: () => context.go('/routes'),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: AppColors.line2),
                  ),
                  child: const Text(
                    '전체 51',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink2,
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S.homeEmpty,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.ink2),
            ),
            const SizedBox(height: AppSpace.x4),
            TextButton(onPressed: () => context.go('/routes'), child: const Text(S.secRoutes)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(S.errNetwork, style: AppType.body.copyWith(color: AppColors.ink2)),
          const SizedBox(height: AppSpace.x3),
          const Text(S.errRetry, style: TextStyle(color: AppColors.routeBlue)),
        ],
      ),
    );
  }
}

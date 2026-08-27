import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/common/placeholder_screen.dart';
import '../features/my/my_screen.dart';
import '../features/my/trip_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/radar/radar_screen.dart';
import '../features/discover/base_screen.dart';
import '../features/discover/course_screen.dart';
import '../features/discover/home_screen.dart';
import '../features/discover/routes_screen.dart';
import '../features/discover/search_screen.dart';
import '../features/discover/spot_screen.dart';
import 'widgets/app_tab_bar.dart';
import 'env.dart';
import 'theme.dart';

/// 라우트 테이블 — TECH_SPEC.md §5와 1:1로 맞춘다.
///
/// M0에서는 모든 화면을 [PlaceholderScreen]으로 선언만 해둔다.
/// 화면을 구현할 때 해당 builder만 교체하면 되므로 라우팅을 다시 손댈 일이 없다.
final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Env.startAt,
  routes: [
    // ── 온보딩 (최초 1회, 탭 밖) ──
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),

    // ── 검색: 모달. 탭바를 덮으므로 셸 밖에 둔다 (SCREENS.md §SR) ──
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, state) =>
          MaterialPage(fullscreenDialog: true, key: state.pageKey, child: const SearchScreen()),
    ),

    // ── 거점 역진입: 코스 없이 진입 (TECH_SPEC §3.7) ──
    GoRoute(path: '/base', builder: (_, _) => const BaseScreen()),

    // ── 3탭 셸 ──
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => _TabScaffold(shell: shell),
      branches: [
        // 탭1 발견
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const HomeScreen(),
              routes: [
                GoRoute(path: 'routes', builder: (_, _) => const RoutesScreen()),
                GoRoute(
                  path: 'course/:id',
                  builder: (_, s) => CourseScreen(courseId: s.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'base',
                      builder: (_, s) => BaseScreen(courseId: s.pathParameters['id']),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'spot/:id',
                  builder: (_, s) => SpotScreen(spotId: s.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),

        // 탭2 레이더 — 다크 고정
        StatefulShellBranch(
          routes: [GoRoute(path: '/radar', builder: (_, _) => const RadarScreen())],
        ),

        // 탭3 마이
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my',
              builder: (_, _) => const MyScreen(),
              routes: [
                GoRoute(
                  path: 'trip/:id',
                  builder: (_, s) => TripScreen(tripId: s.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

/// 3탭 셸 (SCREENS.md §0.2 탭바).
/// 레이더 탭에선 탭바가 다크로 바뀐다.
class _TabScaffold extends StatelessWidget {
  const _TabScaffold({required this.shell});
  final StatefulNavigationShell shell;

  /// 레이더 탭에선 탭바가 다크로 바뀐다 (SCREENS.md §0.2).
  static const _radarIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: shell.currentIndex == _radarIndex ? AppColors.darkBg : AppColors.bg,
      body: shell,
      bottomNavigationBar: AppTabBar(
        index: shell.currentIndex,
        dark: shell.currentIndex == _radarIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

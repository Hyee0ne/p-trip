import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/common/placeholder_screen.dart';
import '../features/my/my_screen.dart';
import '../features/my/trip_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/radar/radar_screen.dart';
import '../features/discover/course_screen.dart';
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
/// ⚠ **라우터마다 새 키를 만든다.** 전역으로 두면 앱을 두 번 띄울 때
///   `!keyReservation.contains(key)`로 터진다 — 테스트가 매번 새로 띄우는데
///   앞 트리가 아직 안 걷혔으면 같은 GlobalKey가 두 곳에 붙는다.
GoRouter buildRouter({String? initialLocation}) {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation ?? Env.startAt,
    routes: [
      // ── 온보딩 (최초 1회, 탭 밖) ──
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),

      // ── 검색: 모달. 탭바를 덮으므로 셸 밖에 둔다 (SCREENS.md §SR) ──
      GoRoute(
        path: '/search',
        parentNavigatorKey: rootKey,
        pageBuilder: (_, state) =>
            MaterialPage(fullscreenDialog: true, key: state.pageKey, child: const SearchScreen()),
        routes: [
          // ⚠ 검색 결과에서 여는 스팟은 **검색 아래**에 쌓아야 한다.
          //   셸 안의 `/spot/:id`로 밀면 루트 내비게이터에 검색이 떠 있는 채로
          //   셸 브랜치가 다시 쌓여 `!keyReservation.contains(key)`로 터진다.
          //   (옛 홈이 목록으로 스팟에 갔던 시절엔 이 경로가 안 쓰여서 안 드러났다)
          GoRoute(
            path: 'spot/:id',
            parentNavigatorKey: rootKey,
            builder: (_, s) => SpotScreen(spotId: s.pathParameters['id']!),
          ),
        ],
      ),

      // ── 3탭 셸 ──
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _TabScaffold(shell: shell),
        branches: [
          // 탭1 발견
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                // ⚠ **홈이 지도다** (2026-08-30 재설계). 옛 홈(스토리 덱·훑어보기)은 지웠다.
                //   목적지가 아니라 길을 고르는 게 이 앱의 진입 문법이라, 지도가 첫 화면이다.
                //   `/routes`도 없앴다 — 두 화면이 같은 일을 하고 있었다.
                builder: (_, _) => const RoutesScreen(),
                routes: [
                  GoRoute(
                    path: 'course/:id',
                    builder: (_, s) => CourseScreen(courseId: s.pathParameters['id']!),
                    routes: [],
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
}

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

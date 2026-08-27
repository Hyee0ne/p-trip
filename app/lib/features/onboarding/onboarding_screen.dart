import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/route_badge.dart';

/// ON 온보딩 3장 (SCREENS.md §ON).
///
/// 로그인을 여기서 강제하지 않는다 — guest로 진입할 수 있다.
/// 권한도 각각 선택 가능하고 건너뛰기를 허용한다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _controller.nextPage(duration: AppMotion.slow, curve: AppMotion.curve);
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/'),
                child: const Text(
                  '건너뛰기',
                  style: TextStyle(color: AppColors.ink3, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [_Concept(), _RouteNumbers(), _Permissions()],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final on = i == _page;
                return AnimatedContainer(
                  duration: AppMotion.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: on ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: on ? AppColors.ink : AppColors.line2,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.x5,
                AppSpace.gutter,
                AppSpace.x6,
              ),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.routeBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(
                    _page == 2 ? '시작하기' : '다음',
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.x6),
    child: Center(child: child),
  );
}

class _Concept extends StatelessWidget {
  const _Concept();
  @override
  Widget build(BuildContext context) {
    return _Page(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RouteBadge('7', size: BadgeSize.lg),
          const SizedBox(height: AppSpace.x8),
          Text(
            '${S.heroLine1}\n${S.heroLine2}',
            textAlign: TextAlign.center,
            style: AppType.h1.copyWith(fontSize: 28, height: 1.44),
          ),
          const SizedBox(height: AppSpace.x4),
          const Text(
            '네비가 못 알려주는 길 위의 발견',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: AppColors.ink2),
          ),
        ],
      ),
    );
  }
}

class _RouteNumbers extends StatelessWidget {
  const _RouteNumbers();
  @override
  Widget build(BuildContext context) {
    return _Page(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: const [
              RouteBadge('1', size: BadgeSize.lg),
              RouteBadge('7', size: BadgeSize.lg),
              RouteBadge('44', size: BadgeSize.lg),
              RouteBadge('46', size: BadgeSize.lg),
            ],
          ),
          const SizedBox(height: AppSpace.x8),
          const Text(
            S.onboard2,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.7, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Permissions extends StatelessWidget {
  const _Permissions();
  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String sub) => Container(
      margin: const EdgeInsets.only(bottom: AppSpace.x3),
      padding: const EdgeInsets.all(AppSpace.x4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.routeBlue),
          const SizedBox(width: AppSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.title),
                const SizedBox(height: 2),
                Text(sub, style: AppType.caption.copyWith(color: AppColors.ink2)),
              ],
            ),
          ),
        ],
      ),
    );

    return _Page(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(Icons.my_location, '위치', S.onboardLocation),
          item(Icons.photo_library_outlined, '사진', S.onboardPhoto),
          const SizedBox(height: AppSpace.x3),
          const Text(
            '각각 선택할 수 있고, 나중에 허용해도 돼요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}

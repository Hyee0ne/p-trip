import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// M0 스캐폴딩용 빈 화면.
///
/// 각 화면을 실제로 구현할 때 이 위젯을 지우고 교체한다.
/// [screenId]는 SCREENS.md의 화면 ID와 일치해야 한다.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.screenId,
    required this.name,
    required this.route,
    this.dark = false,
  });

  final String screenId;
  final String name;
  final String route;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.darkInk : AppColors.ink;
    final fg2 = dark ? AppColors.darkInk2 : AppColors.ink2;
    final fg3 = dark ? AppColors.darkInk3 : AppColors.ink3;

    return Scaffold(
      backgroundColor: dark ? AppColors.darkBg : AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.x3,
                    vertical: AppSpace.x1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.routeBlue,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    screenId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.x4),
                Text(name, style: AppType.h2.copyWith(color: fg)),
                const SizedBox(height: AppSpace.x2),
                Text(route, style: AppType.caption.copyWith(color: fg3)),
                const SizedBox(height: AppSpace.x5),
                Text(
                  'docs/SCREENS.md §$screenId 참조',
                  textAlign: TextAlign.center,
                  style: AppType.caption.copyWith(color: fg2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

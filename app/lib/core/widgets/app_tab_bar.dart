import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';

/// 3탭 탭바 (SCREENS.md §0.2).
///
/// ⚠ Material 3 `NavigationBar`를 쓰지 않는다 — 알약 인디케이터·고정 높이·자체 타이포가
///   시안과 충돌한다. 시안대로 직접 그린다. 레이더 탭에선 다크로 바뀐다.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.index, required this.onTap, required this.dark});

  final int index;
  final ValueChanged<int> onTap;
  final bool dark;

  static const _items = <(IconData, IconData, String)>[
    (Icons.explore_outlined, Icons.explore, S.tabDiscover),
    (Icons.radar_outlined, Icons.radar, S.tabRadar),
    (Icons.person_outline_rounded, Icons.person_rounded, S.tabMy),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bg = dark ? const Color(0xF212100D) : const Color(0xF5FFFFFF);
    final line = dark ? AppColors.darkLine : AppColors.line;
    final off = dark ? AppColors.darkInk3 : AppColors.ink3;
    final on = dark ? AppColors.darkInk : AppColors.routeBlue;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: line, width: 1)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 10),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _Tab(
                  icon: _items[i].$1,
                  activeIcon: _items[i].$2,
                  label: _items[i].$3,
                  selected: i == index,
                  onColor: on,
                  offColor: off,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onColor,
    required this.offColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color onColor;
  final Color offColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = selected ? onColor : offColor;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        splashColor: onColor.withValues(alpha: 0.06),
        highlightColor: onColor.withValues(alpha: 0.04),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                size: 23,
                color: c,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: c,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

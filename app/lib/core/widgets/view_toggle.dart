import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../strings.dart';
import '../theme.dart';
import '../view_mode.dart';

/// 「한 곳씩 ⇄ 훑어보기」 토글 (SCREENS.md §0.1·§0.2).
///
/// 선택된 쪽만 라벨을 보여준다. 상태는 글로벌이라 홈과 코스 상세가 공유한다.
/// ⚠ 레이더에는 이 토글을 두지 않는다.
class ViewToggle extends ConsumerWidget {
  const ViewToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEFF0),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(
            ref,
            Icons.crop_portrait,
            S.viewOneByOne,
            mode == ViewMode.oneByOne,
            ViewMode.oneByOne,
          ),
          const SizedBox(width: 2),
          _seg(
            ref,
            Icons.grid_view_rounded,
            S.viewBrowse,
            mode == ViewMode.browse,
            ViewMode.browse,
          ),
        ],
      ),
    );
  }

  Widget _seg(WidgetRef ref, IconData icon, String label, bool on, ViewMode target) {
    return GestureDetector(
      onTap: () => ref.read(viewModeProvider.notifier).set(target),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: on ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          boxShadow: on
              ? const [BoxShadow(color: Color(0x241E4650), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: on ? AppColors.ink : AppColors.ink2),
            if (on) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

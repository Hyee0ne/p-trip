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
            Icons.wysiwyg_rounded,
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
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(viewModeProvider.notifier).set(target),
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.curve,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: on ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            boxShadow: on
                ? const [BoxShadow(color: Color(0x1F1E4650), blurRadius: 5, offset: Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: on ? AppColors.ink : AppColors.ink3),
              // 선택된 쪽만 라벨을 편다 — 접힘/펼침이 어느 쪽이 켜졌는지 알려준다
              AnimatedSize(
                duration: AppMotion.base,
                curve: AppMotion.curve,
                child: on
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            height: 1,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

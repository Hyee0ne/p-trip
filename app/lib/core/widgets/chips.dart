import 'package:flutter/material.dart';
import '../../data/models/models.dart';
import '../theme.dart';

/// 시의성 칩 — '오늘만' '일몰' '밥때' 등.
class TimelinessChip extends StatelessWidget {
  const TimelinessChip(this.timeliness, {super.key, this.compact = false});

  final Timeliness timeliness;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (timeliness) {
      Timeliness.marketDay => ('오늘만', AppColors.tintRed, AppColors.onTintRed),
      Timeliness.sunset => ('일몰', AppColors.tintGreen, AppColors.onTintGreen),
      Timeliness.mealtime => ('밥때', AppColors.tintSun, AppColors.onTintSun),
      Timeliness.endingSoon => ('이번 주까지', AppColors.tintSun, AppColors.onTintSun),
      Timeliness.none => ('', Colors.transparent, Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      height: compact ? 20 : 28,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 10.5 : 12.5,
          height: 1,
        ),
      ),
    );
  }
}

/// 필터 칩 (SCREENS.md §0.2).
/// ⚠ 밖에 두는 건 '오늘만' '가까운 곳' 둘뿐. 나머지는 [FilterMoreChip] 뒤 시트로.
class DiscoverFilterChip extends StatelessWidget {
  const DiscoverFilterChip({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: selected ? null : Border.all(color: AppColors.line2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink2,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// '[필터] N' — 켜진 개수만 표시한다.
class FilterMoreChip extends StatelessWidget {
  const FilterMoreChip({super.key, this.activeCount = 0, this.onTap});

  final int activeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = activeCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: on ? null : Border.all(color: AppColors.line2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 14, color: on ? Colors.white : AppColors.ink2),
            const SizedBox(width: 5),
            Text(
              on ? '$activeCount' : '필터',
              style: TextStyle(
                color: on ? Colors.white : AppColors.ink2,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

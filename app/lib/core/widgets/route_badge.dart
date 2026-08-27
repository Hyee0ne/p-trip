import 'package:flutter/material.dart';
import '../theme.dart';

enum BadgeSize { sm, md, lg }

/// 국도 표지판 뱃지 — 이 앱의 시그니처 (SCREENS.md §0.2).
///
/// 실제 도로 표지판 형태를 지킨다: 파란 타원 + 흰 테두리 + 흰 숫자.
/// [drivable]이 false면 회색 (북한 구간).
class RouteBadge extends StatelessWidget {
  const RouteBadge(this.label, {super.key, this.size = BadgeSize.md, this.drivable = true});

  final String label;
  final BadgeSize size;
  final bool drivable;

  @override
  Widget build(BuildContext context) {
    final (h, fs, bw, minW) = switch (size) {
      BadgeSize.sm => (22.0, 12.0, 1.5, 30.0),
      BadgeSize.md => (27.0, 14.5, 2.0, 37.0),
      BadgeSize.lg => (34.0, 18.0, 2.5, 47.0),
    };
    return Container(
      height: h,
      constraints: BoxConstraints(minWidth: minW),
      padding: EdgeInsets.symmetric(horizontal: h * 0.34),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: drivable ? AppColors.routeBlue : const Color(0xFFB4C0C2),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: Colors.white, width: bw),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: fs,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

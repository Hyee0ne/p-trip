import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../strings.dart';
import '../theme.dart';
import 'chips.dart';
import 'route_badge.dart';
import 'spot_image.dart';

/// 섹션 라벨 — 조용하게. 훑어보기에선 제목만 쓰고 보조라벨을 붙이지 않는다.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(text, style: AppType.label.copyWith(color: AppColors.ink3)),
        if (trailing != null) ...[
          const Spacer(),
          Text(trailing!, style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
        ],
      ],
    );
  }
}

/// 훑어보기용 2열 그리드 카드 (SCREENS.md §0.2).
/// 보조설명은 **한 줄만**. 두 개를 붙이지 않는다.
class SpotGridCard extends StatelessWidget {
  const SpotGridCard({super.key, required this.spot, this.onTap, this.saved = false});

  final Spot spot;
  final VoidCallback? onTap;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SpotImage(type: spot.type, height: 118, width: double.infinity, radius: 16),
              if (spot.timeliness != Timeliness.none)
                Positioned(left: 8, top: 8, child: TimelinessChip(spot.timeliness, compact: true)),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(color: Color(0xE6FFFFFF), shape: BoxShape.circle),
                  child: Icon(
                    saved ? Icons.favorite : Icons.favorite_border,
                    size: 15,
                    color: saved ? AppColors.marketRed : AppColors.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            spot.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.title.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            '국도에서 ${spot.detourMin}분',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppColors.ink2),
          ),
        ],
      ),
    );
  }
}

/// 검색 결과·코스 목록용 리스트 행 (SCREENS.md §0.2).
class SpotListRow extends StatelessWidget {
  const SpotListRow({super.key, required this.spot, this.onTap, this.saved = false});

  final Spot spot;
  final VoidCallback? onTap;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final sub = spot.blurb.isEmpty
        ? '국도에서 ${spot.detourMin}분'
        : '국도에서 ${spot.detourMin}분 · ${spot.blurb}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SpotImage(type: spot.type, width: 60, height: 60, radius: 13),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          spot.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.title.copyWith(fontSize: 15),
                        ),
                      ),
                      if (spot.timeliness != Timeliness.none) ...[
                        const SizedBox(width: 6),
                        TimelinessChip(spot.timeliness, compact: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: AppColors.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              saved ? Icons.favorite : Icons.favorite_border,
              size: 15,
              color: saved ? AppColors.marketRed : AppColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

/// 「한 곳씩」·DR-02용 전면 카드 (SCREENS.md §0.2).
///
/// 사진이 화면을 채우고 하단 그라데이션 위에 텍스트가 얹힌다.
/// 액션은 원형 3개 — 주 버튼 82pt, 보조 60pt. 운전 중 조작 조건이다.
class FullBleedSpotCard extends StatelessWidget {
  const FullBleedSpotCard({
    super.key,
    required this.spot,
    required this.routeName,
    this.headline,
    this.onVisit,
    this.onSave,
    this.onSkip,
    this.drive = false,
  });

  final Spot spot;
  final String routeName;

  /// 존재형 문구. 없으면 스팟 이름을 쓴다.
  final String? headline;
  final VoidCallback? onVisit;
  final VoidCallback? onSave;
  final VoidCallback? onSkip;

  /// 운전 중(DR-02)이면 제목·본문·버튼을 더 크게 잡는다.
  final bool drive;

  @override
  Widget build(BuildContext context) {
    final primary = drive ? AppTouch.drivePrimary : 64.0;
    final secondary = drive ? AppTouch.driveSecondary : 52.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        SpotImage(type: spot.type, radius: drive ? 0 : AppRadius.hero),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(drive ? 0 : AppRadius.hero),
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xCC140E08), Color(0x33140E08), Color(0x00140E08)],
              stops: [0, 0.42, 0.62],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: drive ? 132 : 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (spot.timeliness != Timeliness.none) TimelinessChip(spot.timeliness),
              const SizedBox(height: 12),
              Text(
                headline ?? spot.name,
                style: (drive ? AppType.drive : AppType.h1).copyWith(color: Colors.white),
              ),
              if (spot.timelinessNote.isNotEmpty || spot.blurb.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  spot.timelinessNote.isNotEmpty ? spot.timelinessNote : spot.blurb,
                  style: (drive ? AppType.driveBody : AppType.body).copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  RouteBadge('${spot.routeId}', size: BadgeSize.sm),
                  const SizedBox(width: 8),
                  Text(
                    routeName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: drive ? 26 : 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circle(Icons.close, secondary, onSkip, drive, muted: true),
              SizedBox(width: drive ? 20 : 16),
              _primary(primary, onVisit, drive),
              SizedBox(width: drive ? 20 : 16),
              _circle(Icons.favorite_border, secondary, onSave, drive),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circle(
    IconData icon,
    double size,
    VoidCallback? onTap,
    bool drive, {
    bool muted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: drive ? const Color(0x24FFFFFF) : AppColors.surface,
          border: Border.all(
            color: drive ? const Color(0x57FFFFFF) : AppColors.line2,
            width: drive ? 1.5 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: drive ? 26 : 22,
          color: drive ? Colors.white : (muted ? AppColors.ink3 : AppColors.marketRed),
        ),
      ),
    );
  }

  Widget _primary(double size, VoidCallback? onTap, bool drive) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: drive ? Colors.white : AppColors.routeBlue,
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.near_me, size: 26, color: drive ? const Color(0xFF12100D) : Colors.white),
            if (drive)
              const Text(
                S.cardVisit,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF12100D),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

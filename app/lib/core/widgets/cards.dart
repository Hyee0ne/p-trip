import 'package:flutter/material.dart';

import 'heart_button.dart';

import '../../data/models/models.dart';
import '../strings.dart';
import '../theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../saves.dart';
import 'app_toast.dart';
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
  const SpotGridCard({super.key, required this.spot, this.onTap});

  final Spot spot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SpotImage(
                type: spot.type,
                spotId: spot.id,
                height: 118,
                width: double.infinity,
                radius: 16,
              ),
              if (spot.timeliness != Timeliness.none)
                Positioned(left: 8, top: 8, child: TimelinessChip(spot.timeliness, compact: true)),
              // 터치 영역 44 · 보이는 원 30 — 한 위젯이 둘 다 소유한다
              Positioned(
                right: 2,
                top: 2,
                child: HeartButton(
                  spotId: spot.id,
                  iconSize: 15,
                  chipSize: 30,
                  color: AppColors.ink2,
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
  const SpotListRow({super.key, required this.spot, this.onTap});

  final Spot spot;
  final VoidCallback? onTap;

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
            SpotImage(type: spot.type, spotId: spot.id, width: 60, height: 60, radius: 13),
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
            HeartButton(spotId: spot.id),
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
    this.showActions = true,
  });

  final Spot spot;
  final String routeName;
  final String? headline;
  final VoidCallback? onVisit;
  final VoidCallback? onSave;
  final VoidCallback? onSkip;

  /// 운전 중(DR-02)이면 제목·본문·버튼을 더 크게 잡는다.
  final bool drive;

  /// 「한 곳씩」에선 액션을 카드 밖(밝은 배경)에 두므로 false로 준다.
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final radius = drive ? 0.0 : AppRadius.hero;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SpotImage(type: spot.type, spotId: spot.id, radius: 0),
          // 아래에서 위로 어두워지는 스크림 — 글자 대비 확보 (4.5:1)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xF215100B),
                  Color(0xB315100B),
                  Color(0x2E15100B),
                  Color(0x0015100B),
                ],
                stops: [0, 0.30, 0.58, 0.80],
              ),
            ),
          ),
          // 내용 + 액션을 한 Column에 쌓는다. 겹치지 않는다.
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, drive ? 26 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (spot.timeliness != Timeliness.none) ...[
                  _glassChip(_timelinessLabel(spot.timeliness)),
                  const SizedBox(height: 12),
                ],
                Text(
                  headline ?? spot.name,
                  style: (drive ? AppType.drive : AppType.h1).copyWith(color: Colors.white),
                ),
                if (spot.timelinessNote.isNotEmpty || spot.blurb.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    spot.timelinessNote.isNotEmpty ? spot.timelinessNote : spot.blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (drive ? AppType.driveBody : AppType.body).copyWith(
                      color: const Color(0xE6FFFFFF),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    RouteBadge('${spot.routeId}', size: BadgeSize.sm),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        routeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xD9FFFFFF),
                        ),
                      ),
                    ),
                  ],
                ),
                if (showActions) ...[
                  SizedBox(height: drive ? 26 : 20),
                  DiscoveryActions(
                    spotId: spot.id,
                    drive: drive,
                    onVisit: onVisit,
                    onSave: onSave,
                    onSkip: onSkip,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _timelinessLabel(Timeliness t) => switch (t) {
    Timeliness.marketDay => '오늘만',
    Timeliness.sunset => '일몰 전',
    Timeliness.mealtime => '지금이 밥때',
    Timeliness.endingSoon => '이번 주까지',
    Timeliness.none => '',
  };

  /// 사진 위 칩 — 유리 느낌. 내용만큼만 차지한다.
  Widget _glassChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x38FFFFFF),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: const Color(0x3DFFFFFF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

/// 발견 액션 3종 — 넘기기 / 들르기 / 찜 (SCREENS.md §0.2).
///
/// 「한 곳씩」에선 카드 밖 밝은 배경 위에([onLight]), DR-02에선 사진 위에 얹힌다.
class DiscoveryActions extends ConsumerWidget {
  const DiscoveryActions({
    super.key,
    required this.spotId,
    this.drive = false,
    this.onLight = false,
    this.onVisit,
    this.onSave,
    this.onSkip,
  });

  final String spotId;
  final bool drive;
  final bool onLight;
  final VoidCallback? onVisit;
  final VoidCallback? onSave;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = drive ? AppTouch.drivePrimary : 62.0;
    final secondary = drive ? AppTouch.driveSecondary : 50.0;
    final liked = ref.watch(savesProvider).isLiked(spotId);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circle(Icons.close_rounded, secondary, onSkip, muted: true),
        SizedBox(width: drive ? 20 : 18),
        _primaryBtn(primary),
        SizedBox(width: drive ? 20 : 18),
        _circle(
          liked ? Icons.favorite : Icons.favorite_border,
          secondary,
          () {
            final added = ref.read(savesProvider.notifier).toggleLike(spotId);
            if (added) showAppToast(context, S.toastSaved);
            onSave?.call();
          },
          tint: onLight ? AppColors.marketRed : null,
        ),
      ],
    );
  }

  Widget _circle(
    IconData icon,
    double size,
    VoidCallback? onTap, {
    bool muted = false,
    Color? tint,
  }) {
    return _Tappable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onLight ? AppColors.surface : const Color(0x2BFFFFFF),
          border: Border.all(
            color: onLight ? AppColors.line2 : const Color(0x5EFFFFFF),
            width: 1.4,
          ),
          boxShadow: onLight ? AppShadow.card : null,
        ),
        child: Icon(
          icon,
          size: size * 0.42,
          color:
              tint ?? (onLight ? AppColors.ink3 : (muted ? const Color(0xD1FFFFFF) : Colors.white)),
        ),
      ),
    );
  }

  Widget _primaryBtn(double size) {
    return _Tappable(
      onTap: onVisit,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onLight ? AppColors.routeBlue : Colors.white,
          boxShadow: [
            BoxShadow(
              color: onLight ? const Color(0x5C1D4ED8) : const Color(0x59000000),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.near_me_rounded,
              size: size * 0.34,
              color: onLight ? Colors.white : const Color(0xFF15100B),
            ),
            if (drive)
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text(
                  S.cardVisit,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: Color(0xFF15100B),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 눌림 피드백 — 레이아웃을 밀지 않고 크기만 살짝 줄인다 (pro-rules: 안정적 상호작용 상태).
class _Tappable extends StatefulWidget {
  const _Tappable({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Tappable> createState() => _TappableState();
}

class _TappableState extends State<_Tappable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}

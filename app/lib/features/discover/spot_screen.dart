import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/saves.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/heart_button.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../handoff/handoff_sheet.dart';

/// CO-03 스팟 상세 (SCREENS.md CO-03).
///
/// 마을·밥집·뷰포인트·문화시설·숙박·캠핑장·시장을 **전부 동급**으로 다룬다.
/// ⚠ 별점·후기 점수·방문자 랭킹을 표기하지 않는다 (원칙 3).
///   신뢰는 확신도 문구와 '들른 차들은 다음에'로만 만든다.
class SpotScreen extends ConsumerWidget {
  const SpotScreen({super.key, required this.spotId});
  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(spotProvider(spotId));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, _) => const Center(child: Text(S.errNetwork)),
        data: (spot) => spot == null ? const Center(child: Text(S.errNetwork)) : _Body(spot: spot),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.spot});
  final Spot spot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 영업정보·사진이 모두 없으면 확신도 문구를 강조하고 한 줄을 더 붙인다 (§CO-03 상태)
    final shallow = !spot.hasPhoto && spot.openHours == null && spot.tel == null;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 124),
          children: [
            _hero(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x5, AppSpace.gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (spot.timeliness != Timeliness.none) ...[
                    TimelinessChip(spot.timeliness),
                    const SizedBox(height: 11),
                  ],
                  Text(spot.name, style: AppType.h1.copyWith(fontSize: 25)),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      RouteBadge('${spot.routeId}', size: BadgeSize.sm),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '국도에서 ${spot.detourMin}분${spot.addr == null ? '' : ' · ${spot.addr}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.ink2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.x5),
            _infoBlock(),
            const SizedBox(height: AppSpace.x3),
            _trustNotice(context, shallow),
            _nextVisits(ref, context),
          ],
        ),
        _floatingBar(context),
        _bottomCta(context),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    return SpotImage(
      type: spot.type,
      spotId: spot.id,
      imageUrl: spot.imageUrl,
      height: 250,
      width: double.infinity,
      radius: 0,
    );
  }

  Widget _floatingBar(BuildContext context) {
    Widget btn(IconData icon, VoidCallback onTap, {Color? color}) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(color: Color(0xEBFFFFFF), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: color ?? AppColors.ink),
      ),
    );
    return Positioned(
      top: MediaQuery.of(context).padding.top + 6,
      left: 14,
      right: 14,
      child: Row(
        children: [
          btn(Icons.arrow_back_ios_new, () => context.pop()),
          const Spacer(),
          HeartButton(
            target: SaveRef.spot(spot.id),
            iconSize: 20,
            chipSize: 38,
            tapSize: 44,
            color: AppColors.ink,
          ),
          btn(Icons.ios_share, () {}),
        ],
      ),
    );
  }

  /// 데이터 있는 항목만 행을 그린다 — 빈 값으로 남기지 않는다 (§CO-03).
  Widget _infoBlock() {
    final rows = <(String, String)>[
      if (spot.timelinessNote.isNotEmpty) ('여는 날', spot.timelinessNote),
      if (spot.openHours != null) ('시간', spot.openHours!),
      if (spot.tel != null) ('전화', spot.tel!),
      if (spot.parking != null) ('주차', spot.parking!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadow.card,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        rows[i].$1,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.ink3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].$2,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              if (i != rows.length - 1)
                const Divider(height: 1, thickness: 1, color: AppColors.line),
            ],
          ],
        ),
      ),
    );
  }

  Widget _trustNotice(BuildContext context, bool shallow) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: shallow ? AppColors.tintSun : const Color(0xFFF2F6F7),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.trustNotice,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.65,
                fontWeight: shallow ? FontWeight.w700 : FontWeight.w400,
                color: shallow ? AppColors.onTintSun : AppColors.ink2,
              ),
            ),
            if (shallow) ...[
              const SizedBox(height: 4),
              const Text(
                S.spotShallow,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onTintSun,
                ),
              ),
            ],
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(child: _linkBtn(Icons.call_outlined, S.trustCall, () => _call())),
                const SizedBox(width: 8),
                Expanded(child: _linkBtn(Icons.open_in_new, S.trustReviews, () => _openReviews())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.line2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: AppColors.ink),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call() async {
    if (spot.tel == null) return;
    await launchUrl(Uri.parse('tel:${spot.tel}'));
  }

  /// 후기는 **링크로 열어줄 뿐** 내용을 가져오거나 저장하지 않는다 (원칙 3).
  Future<void> _openReviews() async {
    final q = Uri.encodeComponent('${spot.addr ?? ''} ${spot.name}'.trim());
    await launchUrl(
      Uri.parse('https://search.naver.com/search.naver?query=$q'),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _nextVisits(WidgetRef ref, BuildContext context) {
    final async = ref.watch(nextVisitsProvider(spot.id));
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (spots) {
        // 없으면 섹션 자체를 그리지 않는다 (빈 상태 문구 없음 — §CO-03)
        if (spots.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x6, AppSpace.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel(S.spotNextVisits, trailing: S.spotNextVisitsSub),
              const SizedBox(height: AppSpace.x3),
              for (var i = 0; i < spots.length; i++) ...[
                SpotListRow(spot: spots[i], onTap: () => context.push('/spot/${spots[i].id}')),
                if (i != spots.length - 1)
                  const Divider(height: 1, thickness: 1, color: AppColors.line),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _bottomCta(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 12, AppSpace.gutter, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [AppColors.bg, AppColors.bg, Color(0x00F6FAFB)],
            stops: [0, 0.66, 1],
          ),
        ),
        child: SizedBox(
          height: 56,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.routeBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
            onPressed: () =>
                HandoffSheet.show(context, mode: HandoffMode.visit, destinationName: spot.name),
            icon: const Icon(Icons.near_me, size: 18),
            label: const Text(
              S.spotNavigate,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

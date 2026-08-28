import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';

/// MY-02 자동 여행기 (SCREENS.md MY-02).
///
/// 실패까지 포함한 하루의 서사화. 허탕도 담담한 톤으로 기록한다.
/// ⚠ 서체는 고딕(Pretendard) — 명조 쓰지 않는다 (2026-08-27 결정).
class TripScreen extends ConsumerWidget {
  const TripScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripProvider(tripId));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, _) => const Center(child: Text(S.errNetwork)),
        data: (t) => t == null ? const Center(child: Text(S.errNetwork)) : _Body(trip: t),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _appBar(context),
          _header(),
          const SizedBox(height: AppSpace.x5),
          _photoCollage(),
          const SizedBox(height: AppSpace.x5),
          _statChips(),
          const SizedBox(height: AppSpace.x8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: SectionLabel(S.tripTimeline),
          ),
          const SizedBox(height: AppSpace.x3),
          _timeline(),
          const SizedBox(height: AppSpace.x5),
          _photoNote(),
          const SizedBox(height: AppSpace.x3),
          _footer(),
          const SizedBox(height: AppSpace.x6),
          _actions(context),
        ],
      ),
    );
  }

  Widget _appBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 14, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.canPop() ? context.pop() : context.go('/my'),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.ios_share, size: 20, color: AppColors.ink3),
            onPressed: () => showAppToast(context, S.tripShareToast),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trip.date} · EP.${trip.episode}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Text(trip.title, style: AppType.h1),
          const SizedBox(height: 14),
          Row(
            children: [
              RouteBadge('${trip.routeId}', size: BadgeSize.sm),
              const SizedBox(width: 9),
              Text(
                '${trip.startName} → ${trip.endName} · ${trip.distanceKm}km',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.ink2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 사진 콜라주 — 큰 것 하나 + 작은 것 둘. 마지막에 +N.
  Widget _photoCollage() {
    final stops = [...trip.stops];
    final types = stops.map((s) => s.type).toList();
    final ids = stops.map<String?>((s) => s.spotId).toList();
    while (types.length < 3) {
      types.add(SpotType.attraction);
      ids.add(null);
    }
    return SizedBox(
      height: 186,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            Expanded(
              flex: 13,
              child: SpotImage(type: types[0], spotId: ids[0], radius: 15),
            ),
            const SizedBox(width: 5),
            Expanded(
              flex: 10,
              child: Column(
                children: [
                  Expanded(
                    child: SpotImage(type: types[1], spotId: ids[1], radius: 15),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SpotImage(type: types[2], spotId: ids[2], radius: 15),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xEBFFFFFF),
                              borderRadius: BorderRadius.circular(AppRadius.chip),
                            ),
                            child: Text(
                              '+${trip.photoCount - 2}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 통계는 표가 아니라 칩으로 조용히. 허탕도 같은 크기로 담담하게.
  Widget _statChips() {
    // ⚠ width 없는 Container에 alignment를 주면 폭이 최대까지 팽창한다 → Row(min)
    Widget chip(String label, Color bg, Color fg) => Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          chip('${S.statVisited} ${trip.visited}', AppColors.tintGreen, AppColors.onTintGreen),
          chip('${S.statPassed} ${trip.passed}', AppColors.fill, AppColors.ink2),
          if (trip.skunked > 0)
            chip('${S.statSkunked} ${trip.skunked}', AppColors.tintSun, AppColors.onTintSun),
          chip('사진 ${trip.photoCount}장', AppColors.fill, AppColors.ink2),
        ],
      ),
    );
  }

  Widget _timeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          for (var i = 0; i < trip.stops.length; i++) ...[
            _StopRow(stop: trip.stops[i]),
            if (i != trip.stops.length - 1)
              const Divider(height: 1, thickness: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }

  Widget _photoNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          const Icon(Icons.photo_camera_outlined, size: 13, color: AppColors.ink3),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              S.photoCaption(trip.photoCount),
              style: const TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Text(
        S.tripFooter(trip.distanceKm),
        style: const TextStyle(fontSize: 12.5, color: AppColors.ink2, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              onPressed: () => showAppToast(context, S.tripShareToast),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text(
                S.tripShare,
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.x5),
          // 탭이 아니라 문장 하나. 숙소를 팔지 않는다 (원칙 4).
          GestureDetector(
            onTap: () => showAppToast(context, '주변 숙박 정보는 준비 중이에요'),
            child: const Text(
              S.oneMoreDay,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.ink2,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop});
  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    // 스쳐간 곳·허탕은 흐리게 — 실패를 숨기지 않되 소리를 낮춘다
    final dim = stop.kind != StopKind.visited;
    return Opacity(
      opacity: dim ? 0.62 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                stop.at,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.ink3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SpotImage(type: stop.type, spotId: stop.spotId, width: 44, height: 44, radius: 11),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          stop.spotName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.title.copyWith(fontSize: 14.5),
                        ),
                      ),
                      if (stop.kind == StopKind.skunked) ...[
                        const SizedBox(width: 6),
                        Container(
                          height: 19,
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.tintSun,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: const Text(
                            S.statSkunked,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onTintSun,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (stop.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      stop.note,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 12, color: AppColors.ink2),
                    ),
                  ],
                ],
              ),
            ),
            if (stop.stayMin != null)
              Text(
                '${stop.stayMin}분',
                style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/trip_log.dart';
import '../../core/cover_store.dart';
import '../../core/widgets/trip_cover.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import 'route_sketch.dart';
import 'share_card.dart';

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

class _Body extends ConsumerWidget {
  const _Body({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 코스에 뭐가 있었는지 알아야 '계획에 없던' 밥을 셀 수 있다.
    final planned = trip.courseId.isEmpty
        ? const <String>{}
        : (ref.watch(courseProvider(trip.courseId)).value?.spotIds ?? const []).toSet();
    final path = ref.watch(tripLogProvider.notifier).pointsOf(trip.id);
    final meals = trip.unplannedMeals(planned);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _appBar(context),
          _header(),
          // 지나온 길. 공유 카드와 같은 선인데 **여기선 통째로** 그린다 — 내 기기 안이다.
          //   점이 둘 미만이면(방금 시작·강제 종료) 상자를 그리지 않는다. 없는 길을 채우지 않는다.
          if (path.length >= 2) ...[
            const SizedBox(height: AppSpace.x4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              // 포스터 — 출발·도착·들른 곳·눈금·거리 (2026-09-09 시안 B).
              child: RouteSketch(
                points: path,
                height: 240,
                stops: trip.stops,
                distanceKm: trip.distanceKm,
                startName: trip.startName,
                endName: trip.endName,
                routeId: trip.routeId,
                routeIds: trip.routeIds,
                splits: [
                  for (final s in trip.segmentsOrSelf.skip(1))
                    if (s.atEpoch > 0) DateTime.fromMillisecondsSinceEpoch(s.atEpoch * 1000),
                ],
                startedAt: trip.startedAt,
                endedAt: trip.endedAt,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.x5),
          // ⚠ ~~사진 스트립~~ → **지웠다 (2026-09-09).** 여행 시간대의 사진첩을 훑어 늘어놓던 줄이다.
          //   그 시간에 찍은 스크린샷까지 여행 사진으로 실렸고, 무엇인지 설명이 없어 낯선 카드로 읽혔다.
          //   사진첩 권한을 묻는 이유도 이 줄뿐이었다 — 같이 없앴다 (온보딩 「사진」·설정 「사진 접근」).
          // 대표 사진은 사진첩 선택기(PHPicker)로 고른다 — 권한 팝업이 없다.
          _coverRow(context, ref),
          const SizedBox(height: AppSpace.x5),
          const SizedBox(height: AppSpace.x3),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: SectionLabel(S.tripTimeline),
          ),
          const SizedBox(height: AppSpace.x3),
          _timeline(),
          const SizedBox(height: AppSpace.x5),
          const SizedBox(height: AppSpace.x6),
          _actions(context, path, meals),
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
              // 갈아탄 여행은 뱃지를 잇는다 — 43 → 6 (DR-08).
              for (var i = 0; i < trip.routeIds.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(Icons.arrow_forward, size: 12, color: AppColors.ink3),
                  ),
                RouteBadge('${trip.routeIds[i]}', size: BadgeSize.sm),
              ],
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

  /// 대표 사진 — 지금 것 미리보기 + 「사진첩에서 고르기」. 시스템 선택기라 권한 팝업이 없다.
  Widget _coverRow(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          TripCoverThumb(trip: trip, size: 56, radius: 13),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  S.coverTitle,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  trip.coverPath.isNotEmpty || trip.coverPhotoId.isNotEmpty
                      ? S.coverChosen
                      : S.coverAuto,
                  style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('cover-pick'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.line2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () async {
              final name = await CoverStore.pick(trip.id, replacing: trip.coverPath);
              if (name == null || !context.mounted) return;
              ref.read(tripLogProvider.notifier).setCoverFile(trip.id, name);
              showAppToast(context, S.toastCover);
            },
            icon: const Icon(Icons.photo_library_outlined, size: 16),
            label: const Text(
              S.coverPick,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline() {
    // 들른 곳과 갈아탄 국도(첫 구간 제외)를 시각순으로 섞는다 (DR-08). 'HH:mm' 은 그대로 정렬된다.
    final segs = trip.segmentsOrSelf;
    final rows = <(String, Widget)>[
      for (final s in trip.stops) (s.at, _StopRow(stop: s)),
      for (var i = 1; i < segs.length; i++)
        (segs[i].at, _SwitchRow(seg: segs[i], prev: segs[i - 1])),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i].$2,
            if (i != rows.length - 1) const Divider(height: 1, thickness: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, List<TripPoint> path, int meals) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          // ⚠ '시작·끝 300m는 가려져요' 줄과 '하루 더?' 링크는 뺐다 (2026-09-09).
          //   자르기는 코드가 그대로 한다(share_card `trimEnds`) — 말만 안 할 뿐이다.
          _ShareButton(trip: trip, path: path, meals: meals),
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
            SpotImage(
              type: stop.type,
              spotId: stop.spotId,
              imageUrl: stop.imageUrl,
              width: 44,
              height: 44,
              radius: 11,
            ),
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
          ],
        ),
      ),
    );
  }
}

/// 여행기 공유 — **누르면 바로 나간다** (2026-09-07).
///
/// 미리보기 시트를 없앤 대신 상태를 여기서 든다. 카드를 뜨는 데 한두 프레임이 걸려서
/// 그 사이 두 번 눌리면 파일을 두 번 쓰고 공유 시트가 두 번 뜬다.
class _ShareButton extends StatefulWidget {
  const _ShareButton({required this.trip, required this.path, this.meals = 0});

  final Trip trip;
  final List<TripPoint> path;
  final int meals;

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await shareTripCard(
        context,
        trip: widget.trip,
        path: widget.path,
        unplannedMeals: widget.meals,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
        onPressed: _busy ? null : _run,
        icon: const Icon(Icons.ios_share, size: 18),
        label: Text(
          _busy ? S.tripSharing : S.tripShare,
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// 타임라인의 「N번 국도로 갈아탐」 행 (DR-08). 점은 국도 파랑 — 들른 곳(유형색)과 구분된다.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.seg, required this.prev});
  final TripSegment seg;
  final TripSegment prev;

  @override
  Widget build(BuildContext context) {
    final prevKm = (seg.fromKm - prev.fromKm).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              seg.at,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.ink3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.routeBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.tripSwitched(seg.routeId, prev.routeId, prevKm),
              style: AppType.title.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

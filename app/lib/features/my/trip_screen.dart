import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/strings.dart';
import '../../core/trip_log.dart';
import '../../core/cover_store.dart';
import '../../core/trip_photos.dart';
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
    final photos = ref.watch(tripPhotosProvider(trip.id)).value;
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
                startedAt: trip.startedAt,
                endedAt: trip.endedAt,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.x5),
          // 사진이 없으면 자리도 만들지 않는다 — 없는 걸 채우지 않는다.
          if (photos != null && photos.photos.isNotEmpty) ...[
            _photoStrip(context, ref, photos.photos),
            const SizedBox(height: AppSpace.x5),
          ] else if (photos != null && photos.access == PhotoAccess.denied) ...[
            _photoDenied(),
            const SizedBox(height: AppSpace.x5),
          ],
          // 대표 사진은 여행 시간대 밖에서도 고를 수 있어야 한다 (2026-09-09) — 사진첩 선택기.
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
          if (photos != null && photos.photos.isNotEmpty) ...[
            _photoNote(photos.photos.length),
            const SizedBox(height: AppSpace.x3),
          ],
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

  /// 사진 스트립 — **내 사진만.** 라벨은 스팟명·시각 (SCREENS.md MY-02).
  ///
  /// ⚠ 스팟 사진을 내 사진인 척 채우지 않는다. 그건 여행기가 아니라 카탈로그다.
  /// ⚠ 탭하면 **여행기 대표 사진**이 된다 (2026-09-07). 그래서 4장에서 끊지 않는다 —
  ///   가로로 넘기면 전부 나온다. 고를 수 있어야 하는 사진을 숨기면 안 된다.
  Widget _photoStrip(BuildContext context, WidgetRef ref, List<TripPhoto> photos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) => _photoTile(context, ref, photos[i]),
          ),
        ),
        const SizedBox(height: AppSpace.x3),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Text(S.coverHint, style: TextStyle(fontSize: 12, color: AppColors.ink3)),
        ),
      ],
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

  /// ⚠ 사진 위에 **아무것도 얹지 않는다** (2026-09-07). 스팟명·시각 라벨이 있었는데,
  ///   규칙(300m 안에 들른 곳이 있으면 이름, 없으면 시각)이 화면에 드러나 보였다.
  ///   내 사진이 규칙의 결과물처럼 보이면 그건 여행기가 아니다. 사진은 사진으로 둔다.
  Widget _photoTile(BuildContext context, WidgetRef ref, TripPhoto p) {
    final isCover = trip.coverPhotoId == p.asset.id;
    return GestureDetector(
      key: ValueKey('photo-${p.asset.id}'),
      onTap: () {
        ref.read(tripLogProvider.notifier).setCover(trip.id, p.asset.id);
        showAppToast(context, S.toastCover);
      },
      child: Container(
        width: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          // 고른 사진에만 테두리. 뱃지와 같은 말을 두 번 하는 게 아니라, 멀리서도 보이게.
          border: isCover ? Border.all(color: AppColors.routeBlue, width: 2.5) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isCover ? 12.5 : 15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.fill),
              FutureBuilder<Uint8List?>(
                future: p.asset.thumbnailDataWithSize(const ThumbnailSize(300, 380)),
                builder: (_, snap) => snap.data == null
                    ? const SizedBox.shrink()
                    : Image.memory(snap.data!, fit: BoxFit.cover),
              ),
              if (isCover)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.routeBlue,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: const Text(
                      S.coverBadge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 권한이 없을 때. 막지 않고 왜 비어 있는지만 말한다 (SCREENS.md MY-02 상태).
  Widget _photoDenied() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: Container(
      padding: const EdgeInsets.all(AppSpace.x4),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.ink3),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              S.photoDenied,
              style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.ink2),
            ),
          ),
          TextButton(
            onPressed: PhotoManager.openSetting,
            style: TextButton.styleFrom(minimumSize: const Size(0, AppTouch.min)),
            child: const Text(S.photoOpenSettings, style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    ),
  );

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

  Widget _photoNote(int photoCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          const Icon(Icons.photo_camera_outlined, size: 13, color: AppColors.ink3),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              S.photoCaption(photoCount),
              style: const TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.ink3),
            ),
          ),
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

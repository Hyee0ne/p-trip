import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../data/models/models.dart';
import '../cover_store.dart';
import '../theme.dart';
import 'spot_image.dart';

/// 여행기 대표 사진 (MY-01 목록 썸네일 · MY-02 미리보기).
///
/// 우선순위: 사진첩에서 고른 파일(`coverPath`) → 여행 시간대의 내 사진(`coverPhotoId`)
/// → 첫 들른 곳의 스팟 사진(폴백). 없는 걸 지어내지 않는다.
class TripCoverThumb extends StatefulWidget {
  const TripCoverThumb({super.key, required this.trip, this.size = 56, this.radius = 13});

  final Trip trip;
  final double size;
  final double radius;

  @override
  State<TripCoverThumb> createState() => _TripCoverThumbState();
}

class _TripCoverThumbState extends State<TripCoverThumb> {
  /// ⚠ build 마다 새 Future를 만들면 스크롤할 때마다 썸네일을 다시 뜬다. 한 번만 잡는다.
  Future<Uint8List?>? _asset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TripCoverThumb old) {
    super.didUpdateWidget(old);
    if (old.trip.coverPhotoId != widget.trip.coverPhotoId ||
        old.trip.coverPath != widget.trip.coverPath) {
      _load();
    }
  }

  void _load() {
    final id = widget.trip.coverPhotoId;
    _asset = id.isEmpty || widget.trip.coverPath.isNotEmpty
        ? null
        : AssetEntity.fromId(
            id,
          ).then((a) => a?.thumbnailDataWithSize(const ThumbnailSize(300, 300)));
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final fallback = SpotImage(
      type: trip.stops.isEmpty ? SpotType.attraction : trip.stops.first.type,
      spotId: trip.stops.isEmpty ? null : trip.stops.first.spotId,
      imageUrl: trip.stops.isEmpty ? null : trip.stops.first.imageUrl,
      width: widget.size,
      height: widget.size,
      radius: widget.radius,
    );

    Widget box(Widget child) => ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(width: widget.size, height: widget.size, child: child),
    );

    final file = CoverStore.fileFor(trip.coverPath);
    if (file != null) {
      return box(
        Image.file(
          file,
          fit: BoxFit.cover,
          // 파일이 사라졌으면(앱 데이터 정리 등) 폴백. 빈 칸을 두지 않는다.
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }
    final future = _asset;
    if (future == null) return fallback;
    return box(
      FutureBuilder<Uint8List?>(
        future: future,
        builder: (_, snap) {
          if (snap.data != null) return Image.memory(snap.data!, fit: BoxFit.cover);
          // 아직 읽는 중이면 빈 자리. 다 읽었는데 없으면 사진이 지워진 것이다.
          if (snap.connectionState != ConnectionState.done) {
            return const ColoredBox(color: AppColors.fill);
          }
          return fallback;
        },
      ),
    );
  }
}

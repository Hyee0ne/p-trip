import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/models/models.dart';
import 'trip_log.dart';

/// 사진첩 접근 상태. UI는 이 값만 보고 분기한다.
enum PhotoAccess { granted, limited, denied }

/// 여행 시간대에 찍힌 사진 한 장.
class TripPhoto {
  const TripPhoto({required this.asset, required this.at, this.lat, this.lng, this.spotName});

  final AssetEntity asset;
  final DateTime at;

  /// 찍은 자리. EXIF에 있으면 그걸 쓰고, 없으면 촬영 시각을 경로에 보간해서 추정한다.
  /// ⚠ null이면 '모른다'는 뜻이다. 지어내지 않는다.
  final double? lat;
  final double? lng;

  /// 그 자리에서 가장 가까운 들른 곳. 멀면 null — 아무 스팟에나 붙이지 않는다.
  final String? spotName;
}

class TripPhotos {
  const TripPhotos({required this.access, this.photos = const []});

  final PhotoAccess access;
  final List<TripPhoto> photos;
}

/// 여행기의 사진 스트립 (SCREENS.md MY-02).
///
/// **사진을 만들지 않는다.** 그 시간대에 실제로 찍힌 사진만 모아 경로 위에 놓는다.
/// 없으면 스트립을 그리지 않는다 — 스팟 사진을 내 사진인 척 보여주지 않는다.
///
/// ⚠ 사진첩은 사적인 공간이다. **여행 시간창 밖은 아예 조회하지 않는다.**
///   (권한 문구 "여행한 시간대의 사진만 봅니다"가 사실이어야 한다)
final tripPhotosProvider = FutureProvider.family<TripPhotos, String>((ref, tripId) async {
  final log = ref.watch(tripLogProvider.notifier);
  final trip = ref.watch(tripLogProvider).trips.where((t) => t.id == tripId).firstOrNull;
  final path = log.pointsOf(tripId);
  if (trip == null || path.isEmpty) return const TripPhotos(access: PhotoAccess.granted);

  final state = await PhotoManager.requestPermissionExtend();
  if (!state.hasAccess) return const TripPhotos(access: PhotoAccess.denied);
  final access = state == PermissionState.limited ? PhotoAccess.limited : PhotoAccess.granted;

  // 앞뒤 10분은 넉넉히 본다 — 출발 직전·도착 직후 한 장은 그 여행의 사진이다.
  final from = path.first.at.subtract(const Duration(minutes: 10));
  final to = path.last.at.add(const Duration(minutes: 10));

  final assets = await PhotoManager.getAssetListRange(
    start: 0,
    // 하루치 사진 상한. 이보다 많이 찍었으면 앞의 200장으로 충분하다.
    end: 200,
    type: RequestType.image,
    filterOption: FilterOptionGroup(
      createTimeCond: DateTimeCond(min: from, max: to),
      orders: [const OrderOption(type: OrderOptionType.createDate)],
    ),
  );

  final out = <TripPhoto>[];
  for (final a in assets) {
    final at = a.createDateTime;
    // ⚠ iOS는 latitude 게터가 비어 있을 수 있다. 명시적으로 물어야 온다.
    final ll = await a.latlngAsync();
    var lat = ll?.latitude;
    var lng = ll?.longitude;
    // 0,0은 '없음'이지 기니만이 아니다.
    if (lat == 0 && lng == 0) {
      lat = null;
      lng = null;
    }
    if (lat == null || lng == null) {
      final guess = placeByTime(at, path);
      lat = guess?.$1;
      lng = guess?.$2;
    }
    out.add(
      TripPhoto(
        asset: a,
        at: at,
        lat: lat,
        lng: lng,
        spotName: lat == null || lng == null ? null : nearestStop(lat, lng, trip.stops),
      ),
    );
  }
  return TripPhotos(access: access, photos: out);
});

/// 촬영 시각을 경로에 꽂아 위치를 추정한다.
///
/// ⚠ 정차 중에도 점이 찍히기 때문에(2분 규칙) 멈춰서 찍은 사진이 제자리에 놓인다.
///   거리 기준으로만 찍었다면 여기서 위치가 통째로 어긋났다.
@visibleForTesting
(double, double)? placeByTime(DateTime at, List<TripPoint> path) {
  if (path.isEmpty) return null;
  if (!at.isAfter(path.first.at)) return (path.first.lat, path.first.lng);
  if (!at.isBefore(path.last.at)) return (path.last.lat, path.last.lng);

  for (var i = 0; i < path.length - 1; i++) {
    final a = path[i];
    final b = path[i + 1];
    if (at.isBefore(a.at) || at.isAfter(b.at)) continue;
    final span = b.at.difference(a.at).inMilliseconds;
    final t = span <= 0 ? 0.0 : at.difference(a.at).inMilliseconds / span;
    return (a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
  }
  return null;
}

/// 300m 안에 들른 곳이 있으면 그 이름. 없으면 null —
/// 먼 스팟 이름을 붙이면 가보지도 않은 곳의 사진이 된다.
@visibleForTesting
String? nearestStop(double lat, double lng, List<TripStop> stops) {
  String? best;
  var bestKm = 0.3;
  for (final s in stops) {
    if (s.lat == null || s.lng == null) continue;
    final d = _roughKm(lat, lng, s.lat!, s.lng!);
    if (d < bestKm) {
      bestKm = d;
      best = s.spotName;
    }
  }
  return best;
}

/// 대략 거리(km). 위도 37도 평면 근사면 충분하다.
double _roughKm(double aLat, double aLng, double bLat, double bLng) {
  final dx = (bLng - aLng) * 88.0;
  final dy = (bLat - aLat) * 111.0;
  return math.sqrt(dx * dx + dy * dy);
}

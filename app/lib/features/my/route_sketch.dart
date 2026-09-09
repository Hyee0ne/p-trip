import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/models.dart';

/// 지나온 길을 선 하나로 (MY-02 상세 · 공유 카드).
///
/// **지도가 아니다.** 실제 GPS 점을 그대로 잇는다 — 카카오맵은 플랫폼 뷰라 캡처에 안 잡히고,
/// 지도 위에 얹으면 내비처럼 읽힌다 (원칙 1). 선만 있으면 "이렇게 달렸다"로 충분하다.
///
/// ⚠ 자르기는 **부르는 쪽이** 한다. 공유 카드는 시작·끝 300m를 잘라서 넘기고(집·숙소),
///   상세 화면은 내 기기 안이라 통째로 넘긴다. 여기서 다시 자르지 않는다.
class RouteSketch extends StatelessWidget {
  const RouteSketch({super.key, required this.points, required this.height, this.width});

  final List<TripPoint> points;
  final double height;

  /// null 이면 가로를 꽉 채운다.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: height,
        width: width,
        child: ColoredBox(
          color: AppColors.fill,
          child: CustomPaint(painter: RoutePainter(points)),
        ),
      ),
    );
  }

  /// 경로의 가로:세로 비. 너무 납작하거나 너무 좁아지지 않게 잘라둔다.
  /// 공유 카드가 상자를 **경로 모양에 맞출 때** 쓴다 — 남북으로 긴 길을 넓은 상자에 넣으면
  /// 가느다란 선 하나에 좌우가 텅 빈다.
  static double aspect(List<TripPoint> pts) {
    var minLat = pts.first.lat, maxLat = minLat, minLng = pts.first.lng, maxLng = minLng;
    for (final p in pts) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    final x = (maxLng - minLng) * 88.0;
    final y = (maxLat - minLat) * 111.0;
    if (y <= 0) return 1.8;
    return (x / y).clamp(0.62, 1.9);
  }
}

/// 점들을 상자에 맞춰 잇는다.
class RoutePainter extends CustomPainter {
  RoutePainter(this.points);
  final List<TripPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var minLat = points.first.lat, maxLat = minLat;
    var minLng = points.first.lng, maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    // 위도 1도와 경도 1도의 실제 길이가 다르다. 보정 안 하면 길이 납작해진다.
    final spanX = math.max((maxLng - minLng) * 88.0, 1e-6);
    final spanY = math.max((maxLat - minLat) * 111.0, 1e-6);
    const pad = 14.0;
    final scale = math.min((size.width - pad * 2) / spanX, (size.height - pad * 2) / spanY);
    final offX = (size.width - spanX * scale) / 2;
    final offY = (size.height - spanY * scale) / 2;

    Offset at(TripPoint p) => Offset(
      offX + (p.lng - minLng) * 88.0 * scale,
      // 위도는 위로 커지는데 캔버스는 아래로 커진다.
      size.height - offY - (p.lat - minLat) * 111.0 * scale,
    );

    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.routeBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // 양 끝점은 찍지 않는다 — 어디서 시작했는지 강조할 이유가 없다.
  }

  @override
  bool shouldRepaint(RoutePainter old) => old.points != points;
}

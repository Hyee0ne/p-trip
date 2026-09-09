import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../radar/radar_view.dart';

/// 지나온 길 — **포스터** (MY-02 상세 · 공유 카드). 2026-09-09 시안 B.
///
/// **지도가 아니다.** 실제 GPS 점을 그대로 잇는다 — 지도 위에 얹으면 내비처럼 읽힌다 (원칙 1).
/// 선만 있던 걸 포스터로 키웠다: 출발·도착 점과 지명·시각, 들른 곳 점(유형색)과 이름,
/// 10km 눈금, 옅은 모눈, 좌상단 거리·구간, 우상단 국도 뱃지. Strava 프린트의 문법이다.
/// ⚠ ETA·평균속도·페이스는 없다. 시간은 출발·도착·들른 시각뿐.
///
/// ⚠ 자르기는 **부르는 쪽이** 한다. 공유 카드는 시작·끝 300m를 잘라서 넘기고(집·숙소),
///   상세 화면은 내 기기 안이라 통째로 넘긴다. 여기서 다시 자르지 않는다.
class RouteSketch extends StatelessWidget {
  const RouteSketch({
    super.key,
    required this.points,
    required this.height,
    this.width,
    this.stops = const [],
    this.distanceKm,
    this.startName = '',
    this.endName = '',
    this.routeId,
    this.startedAt = '',
    this.endedAt = '',
    this.header = true,
  });

  final List<TripPoint> points;
  final double height;

  /// null 이면 가로를 꽉 채운다.
  final double? width;

  /// 들른 곳. 좌표 있는 `visited` 만 찍는다.
  final List<TripStop> stops;
  final int? distanceKm;
  final String startName;
  final String endName;
  final int? routeId;
  final String startedAt;
  final String endedAt;

  /// 좌상단 거리·구간과 우상단 뱃지. 공유 카드는 제 머리글이 있어 끈다.
  final bool header;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: height,
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: CustomPaint(
            painter: RoutePainter(
              points,
              stops: stops,
              distanceKm: distanceKm,
              startName: startName,
              endName: endName,
              routeId: routeId,
              startedAt: startedAt,
              endedAt: endedAt,
              header: header,
            ),
          ),
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

/// 점들을 상자에 맞춰 잇고, 그 위에 포스터의 글자와 점을 얹는다.
class RoutePainter extends CustomPainter {
  RoutePainter(
    this.points, {
    this.stops = const [],
    this.distanceKm,
    this.startName = '',
    this.endName = '',
    this.routeId,
    this.startedAt = '',
    this.endedAt = '',
    this.header = true,
  });

  final List<TripPoint> points;
  final List<TripStop> stops;
  final int? distanceKm;
  final String startName;
  final String endName;
  final int? routeId;
  final String startedAt;
  final String endedAt;
  final bool header;

  static const _grid = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    if (points.length < 2) return;

    final visited = [
      for (final s in stops)
        if (s.kind == StopKind.visited && s.lat != null && s.lng != null) s,
    ];

    // 경계 — 들른 곳도 넣는다. 길에서 2km 벗어난 점이 상자 밖으로 나가면 안 된다.
    var minLat = points.first.lat, maxLat = minLat;
    var minLng = points.first.lng, maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    for (final s in visited) {
      minLat = math.min(minLat, s.lat!);
      maxLat = math.max(maxLat, s.lat!);
      minLng = math.min(minLng, s.lng!);
      maxLng = math.max(maxLng, s.lng!);
    }
    // 위도 1도와 경도 1도의 실제 길이가 다르다. 보정 안 하면 길이 납작해진다.
    final spanX = math.max((maxLng - minLng) * 88.0, 1e-6);
    final spanY = math.max((maxLat - minLat) * 111.0, 1e-6);
    final padTop = header ? 60.0 : 24.0;
    const padSide = 30.0;
    const padBottom = 30.0;
    final scale = math.min(
      (size.width - padSide * 2) / spanX,
      (size.height - padTop - padBottom) / spanY,
    );
    final offX = padSide + (size.width - padSide * 2 - spanX * scale) / 2;
    final offY = padBottom + (size.height - padTop - padBottom - spanY * scale) / 2;

    Offset at(double lat, double lng) => Offset(
      offX + (lng - minLng) * 88.0 * scale,
      // 위도는 위로 커지는데 캔버스는 아래로 커진다.
      size.height - offY - (lat - minLat) * 111.0 * scale,
    );

    // 선.
    final first = at(points.first.lat, points.first.lng);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final p in points.skip(1)) {
      final o = at(p.lat, p.lng);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.routeBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _paintTicks(canvas, at);

    final placed = <Rect>[];
    // 들른 곳 — 유형색 점 + 이름.
    for (final s in visited) {
      final o = at(s.lat!, s.lng!);
      canvas.drawCircle(o, 5, Paint()..color = radarTypeColors[s.type] ?? AppColors.routeBlue);
      canvas.drawCircle(
        o,
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _label(canvas, size, placed, o, s.spotName, null, const Offset(9, -7));
    }

    // 출발·도착.
    final last = at(points.last.lat, points.last.lng);
    canvas.drawCircle(first, 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      first,
      6,
      Paint()
        ..color = AppColors.routeBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(last, 7.5, Paint()..color = Colors.white);
    canvas.drawCircle(last, 6, Paint()..color = AppColors.routeBlue);
    if (startName.isNotEmpty) {
      _label(canvas, size, placed, first, startName, startedAt, const Offset(-6, 10), bold: true);
    }
    if (endName.isNotEmpty) {
      _label(canvas, size, placed, last, endName, endedAt, const Offset(10, -8), bold: true);
    }

    if (header) _paintHeader(canvas, size);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var x = _grid; x < size.width; x += _grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = _grid; y < size.height; y += _grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// 10km 마다 선에 직각인 눈금. 숫자는 없다 — 리듬만 준다.
  void _paintTicks(Canvas canvas, Offset Function(double, double) at) {
    final paint = Paint()
      ..color = AppColors.routeBlue.withValues(alpha: 0.45)
      ..strokeWidth = 1.5;
    var acc = 0.0;
    var next = 10.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final segKm = math.sqrt(
        math.pow((b.lng - a.lng) * 88.0, 2) + math.pow((b.lat - a.lat) * 111.0, 2),
      );
      while (segKm > 0 && acc + segKm >= next) {
        final t = (next - acc) / segKm;
        final lat = a.lat + (b.lat - a.lat) * t;
        final lng = a.lng + (b.lng - a.lng) * t;
        final o = at(lat, lng);
        final pa = at(a.lat, a.lng), pb = at(b.lat, b.lng);
        final dir = pb - pa;
        if (dir.distance > 0) {
          final n = Offset(-dir.dy, dir.dx) / dir.distance * 4;
          canvas.drawLine(o - n, o + n, paint);
        }
        next += 10;
      }
      acc += segKm;
    }
  }

  /// 점 옆에 이름(과 시각). 오른쪽이 기본, 넘치면 왼쪽, 겹치면 아래.
  void _label(
    Canvas canvas,
    Size size,
    List<Rect> placed,
    Offset anchor,
    String name,
    String? time,
    Offset offset, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        children: [
          TextSpan(
            text: name,
            style: TextStyle(
              fontFamily: AppType.family,
              fontSize: bold ? 11.5 : 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (time != null && time.isNotEmpty)
            TextSpan(
              text: '  $time',
              style: TextStyle(
                fontFamily: AppType.family,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.ink3,
              ),
            ),
        ],
      ),
    )..layout(maxWidth: size.width * 0.6);
    final w = tp.width + 10, h = tp.height + 4;

    Rect candidate(Offset o) => Rect.fromLTWH(o.dx, o.dy, w, h);
    final tries = <Offset>[
      anchor + offset,
      Offset(anchor.dx - offset.dx - w, anchor.dy + offset.dy),
      anchor + Offset(offset.dx, 8),
      Offset(anchor.dx - offset.dx - w, anchor.dy + 8),
      anchor + Offset(offset.dx, -h - 8),
    ];
    Rect? rect;
    for (final o in tries) {
      final r = candidate(o);
      final inside =
          r.left >= 2 && r.right <= size.width - 2 && r.top >= 2 && r.bottom <= size.height - 2;
      final clear = placed.every((p) => !p.overlaps(r.inflate(2)));
      if (inside && clear) {
        rect = r;
        break;
      }
    }
    rect ??= candidate(tries.first);
    placed.add(rect);
    // 글자 뒤에 흰 바탕 — 모눈·선 위에서도 읽힌다.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = Colors.white.withValues(alpha: 0.86),
    );
    tp.paint(canvas, rect.topLeft + const Offset(5, 2));
  }

  /// 좌상단 거리·구간, 우상단 국도 뱃지.
  void _paintHeader(Canvas canvas, Size size) {
    var y = 12.0;
    final km = distanceKm;
    if (km != null) {
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: '${km}km',
          style: TextStyle(
            fontFamily: AppType.family,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.ink,
          ),
        ),
      )..layout();
      tp.paint(canvas, Offset(14, y));
      y += tp.height + 1;
    }
    final sub = [
      if (startName.isNotEmpty && endName.isNotEmpty) '$startName → $endName',
      if (startedAt.isNotEmpty && endedAt.isNotEmpty) '$startedAt–$endedAt',
    ].join(' · ');
    if (sub.isNotEmpty) {
      TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: sub,
            style: TextStyle(
              fontFamily: AppType.family,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.ink3,
            ),
          ),
        )
        ..layout(maxWidth: size.width - 70)
        ..paint(canvas, Offset(14, y));
    }
    final id = routeId;
    if (id != null) {
      final c = Offset(size.width - 14 - 15, 12 + 15);
      canvas.drawCircle(c, 15, Paint()..color = AppColors.routeBlue);
      canvas.drawCircle(
        c,
        15,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: '$id',
          style: TextStyle(
            fontFamily: AppType.family,
            fontSize: id >= 10 ? 12 : 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.points != points ||
      old.stops != stops ||
      old.distanceKm != distanceKm ||
      old.startName != startName ||
      old.endName != endName ||
      old.routeId != routeId ||
      old.startedAt != startedAt ||
      old.endedAt != endedAt ||
      old.header != header;
}

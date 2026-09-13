import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../radar/radar_view.dart';

/// 지나온 길 — **포스터** (MY-02 상세 · 공유 카드). 2026-09-09 시안 B.
///
/// **지도가 아니다.** 실제 GPS 점을 그대로 잇는다 — 지도 위에 얹으면 내비처럼 읽힌다 (원칙 1).
/// 선만 있던 걸 포스터로 키웠다: 출발·도착 점과 지명·시각, 들른 곳 **번호 점**(유형색·들른 순서)과
/// 자리가 있을 때만 이름, 10km 눈금, 옅은 모눈, 좌상단 거리·구간, 우상단 국도 뱃지. Strava 프린트의 문법이다.
/// ⚠ 이름표는 자리가 없으면 **안 쓴다** (2026-09-13). 번호가 목록(공유 카드·타임라인)과 이어 준다.
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
    this.routeIds = const [],
    this.splits = const [],
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

  /// 거쳐 간 국도 번호(DR-08). 둘 이상이면 헤더에 '43 → 6번 국도'.
  final List<int> routeIds;

  /// 갈아탄 시각들 — 경로를 그 시각에서 잘라 구간마다 색을 바꾼다 (파랑·노랑 번갈아).
  final List<DateTime> splits;
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
              routeIds: routeIds,
              splits: splits,
              startedAt: startedAt,
              endedAt: endedAt,
              header: header,
            ),
          ),
        ),
      ),
    );
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
    this.routeIds = const [],
    this.splits = const [],
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

  /// 거쳐 간 국도 번호(DR-08). 둘 이상이면 헤더에 '43 → 6번 국도'.
  final List<int> routeIds;

  /// 갈아탄 시각들 — 경로를 그 시각에서 잘라 구간마다 색을 바꾼다 (파랑·노랑 번갈아).
  final List<DateTime> splits;
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
    // 여백은 상자 폭에 비례한다 (2026-09-13). 30pt 고정이던 때 공유 카드의 105pt 상자에선
    // 좌우 60pt 를 비우고 선을 45pt 안에 구겨 넣었다.
    final padSide = math.max(14.0, size.width * 0.06);
    final padTop = header ? 60.0 : padSide;
    final padBottom = padSide;
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

    // 선 — 갈아탄 시각마다 잘라 구간 색을 번갈아 칠한다 (DR-08). 갈아탄 적 없으면 파랑 하나.
    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const colors = [AppColors.routeBlue, AppColors.sun];
    final first = at(points.first.lat, points.first.lng);
    var seg = 0;
    var path = Path()..moveTo(first.dx, first.dy);
    var prev = first;
    for (final p in points.skip(1)) {
      final o = at(p.lat, p.lng);
      final nextSeg = splits.where((t) => !p.at.isBefore(t)).length;
      if (nextSeg != seg) {
        canvas.drawPath(path, stroke(colors[seg % colors.length]));
        seg = nextSeg;
        path = Path()..moveTo(prev.dx, prev.dy);
      }
      path.lineTo(o.dx, o.dy);
      prev = o;
    }
    canvas.drawPath(path, stroke(colors[seg % colors.length]));

    _paintTicks(canvas, at);

    final placed = <Rect>[];
    final dots = [for (final s in visited) at(s.lat!, s.lng!)];
    final last = at(points.last.lat, points.last.lng);

    // 출발·도착 점.
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

    // 들른 곳 — 유형색 **번호 점** (들른 순서). 번호는 카드 아래 목록과 맞물린다.
    for (var i = 0; i < visited.length; i++) {
      final o = dots[i];
      canvas.drawCircle(
        o,
        8.5,
        Paint()..color = radarTypeColors[visited[i].type] ?? AppColors.routeBlue,
      );
      canvas.drawCircle(
        o,
        8.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            fontFamily: AppType.family,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      )..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    // 이름표는 점을 다 찍은 뒤에 — 다른 점을 덮지 않는 자리에만 놓는다.
    // ⚠ 자리가 없으면 **안 쓴다.** 전에는 그냥 겹쳐 그렸고, 반투명 바탕 밑으로 글자가 비쳐
    //   유령처럼 보였다 (2026-09-13 실기기 공유 카드). 이름은 카드 아래 목록이 전부 맡는다.
    final avoid = [first, last, ...dots];
    if (startName.isNotEmpty) {
      _label(
        canvas,
        size,
        placed,
        avoid,
        first,
        startName,
        startedAt,
        const Offset(-6, 10),
        bold: true,
        force: true,
      );
    }
    if (endName.isNotEmpty) {
      _label(
        canvas,
        size,
        placed,
        avoid,
        last,
        endName,
        endedAt,
        const Offset(10, -8),
        bold: true,
        force: true,
      );
    }
    for (var i = 0; i < visited.length; i++) {
      _label(canvas, size, placed, avoid, dots[i], visited[i].spotName, null, const Offset(12, -8));
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

  /// 10km 마다 선을 가로지르는 흰 눈금. 숫자는 없다 — 리듬만 준다.
  /// ⚠ 파란 눈금은 파란 선 위에서 안 보였다 (시뮬레이터). 선을 가로지르는 흰 금이어야 읽힌다.
  void _paintTicks(Canvas canvas, Offset Function(double, double) at) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in tickLines(points, at)) {
      canvas.drawLine(a, b, paint);
    }
  }

  /// 눈금 선분들. [everyKm] 마다 하나, 선(4.5pt) 양옆으로 [half] 만큼 나온다.
  @visibleForTesting
  static List<(Offset, Offset)> tickLines(
    List<TripPoint> pts,
    Offset Function(double, double) at, {
    double everyKm = 10,
    double half = 6.5,
  }) {
    final out = <(Offset, Offset)>[];
    var acc = 0.0;
    var next = everyKm;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final segKm = math.sqrt(
        math.pow((b.lng - a.lng) * 88.0, 2) + math.pow((b.lat - a.lat) * 111.0, 2),
      );
      while (segKm > 0 && acc + segKm >= next) {
        final t = (next - acc) / segKm;
        final o = at(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
        final dir = at(b.lat, b.lng) - at(a.lat, a.lng);
        if (dir.distance > 0) {
          final n = Offset(-dir.dy, dir.dx) / dir.distance * half;
          out.add((o - n, o + n));
        }
        next += everyKm;
      }
      acc += segKm;
    }
    return out;
  }

  /// 점 옆에 이름(과 시각). 오른쪽이 기본, 넘치면 왼쪽, 겹치면 아래·위.
  /// 한 줄이다 — 12자를 넘으면 "…". 바탕은 불투명한 흰색이라 모눈·선·글자가 비치지 않는다.
  /// 자리가 없으면 그리지 않고 false. [force] 면(출발·도착) 그래도 첫 자리에 그린다.
  bool _label(
    Canvas canvas,
    Size size,
    List<Rect> placed,
    List<Offset> avoid,
    Offset anchor,
    String name,
    String? time,
    Offset offset, {
    bool bold = false,
    bool force = false,
  }) {
    final shown = name.length > 12 ? '${name.substring(0, 11)}…' : name;
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        children: [
          TextSpan(
            text: shown,
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
    )..layout(maxWidth: math.max(60.0, size.width * 0.6));
    final w = tp.width + 10, h = tp.height + 4;

    Rect candidate(Offset o) => Rect.fromLTWH(o.dx, o.dy, w, h);
    final tries = <Offset>[
      anchor + offset,
      Offset(anchor.dx - offset.dx - w, anchor.dy + offset.dy),
      anchor + Offset(offset.dx, 8),
      Offset(anchor.dx - offset.dx - w, anchor.dy + 8),
      Offset(anchor.dx - w / 2, anchor.dy - h - 12),
      Offset(anchor.dx - w / 2, anchor.dy + 12),
    ];
    Rect? rect;
    for (final o in tries) {
      final r = candidate(o);
      final inside =
          r.left >= 2 && r.right <= size.width - 2 && r.top >= 2 && r.bottom <= size.height - 2;
      final clear = placed.every((p) => !p.overlaps(r.inflate(3)));
      // 다른 점(번호)을 덮지 않는다. 제 점은 anchor 라 어차피 바깥이다.
      final dotsClear = avoid.every((d) => d == anchor || !r.inflate(9).contains(d));
      if (inside && clear && dotsClear) {
        rect = r;
        break;
      }
    }
    if (rect == null) {
      if (!force) return false;
      rect = candidate(tries.first);
    }
    placed.add(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = Colors.white,
    );
    tp.paint(canvas, rect.topLeft + const Offset(5, 2));
    return true;
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
      if (routeIds.length > 1) '${routeIds.join(' → ')}번 국도',
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

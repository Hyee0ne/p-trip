import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/geo.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/route_badge.dart';
import '../../data/models/models.dart';

/// 여행기 공유 카드 (SCREENS.md MY-02 §4).
///
/// **보여주고 나서 보낸다.** 무엇이 나가는지 눈으로 확인한 뒤 공유하게 한다 —
/// 경로가 담긴 이미지라 더 그렇다.
///
/// ⚠ 시작·끝 300m는 **아예 잘라낸다** (core/geo.dart `trimEnds`). 집·숙소가 찍히면 안 된다.
/// ⚠ 지도는 우리가 그린다. 카카오맵은 플랫폼 뷰라 `RepaintBoundary`에 **안 잡힌다** —
///   캡처하면 빈 자리가 나온다. 실제 GPS 점으로 선을 그리는 게 정확하기도 하다.
class ShareCardSheet extends StatefulWidget {
  const ShareCardSheet({
    super.key,
    required this.trip,
    required this.path,
    this.nightSky,
    this.unplannedMeals = 0,
  });

  final Trip trip;
  final List<TripPoint> path;
  final String? nightSky;
  final int unplannedMeals;

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required List<TripPoint> path,
    String? nightSky,
    int unplannedMeals = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareCardSheet(
        trip: trip,
        path: path,
        nightSky: nightSky,
        unplannedMeals: unplannedMeals,
      ),
    );
  }

  @override
  State<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<ShareCardSheet> {
  final _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final obj = _boundary.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) return;
      // 3배로 뜬다. 공유된 이미지가 흐리면 카드를 만든 의미가 없다.
      final image = await obj.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final bytes = data.buffer.asUint8List();

      final file = File('${Directory.systemTemp.path}/ptrip-${widget.trip.id}.png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: S.tripTitle(widget.trip.routeName)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = trimEnds(widget.path);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 26),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
            ),
            const SizedBox(height: AppSpace.x5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: RepaintBoundary(key: _boundary, child: _card(trimmed)),
            ),
            const SizedBox(height: AppSpace.x4),
            // 무엇이 가려지는지 카드 밑에 그대로 적는다. 토스트로 흘리지 않는다.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppColors.ink3),
                const SizedBox(width: 6),
                Text(
                  S.tripShareToast,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.ink3),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.x4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  onPressed: _busy ? null : _share,
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Text(
                    _busy ? S.tripSharing : S.tripShare,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 경로의 가로:세로 비. 너무 납작하거나 너무 좁아지지 않게 잘라둔다.
  static double _aspect(List<TripPoint> pts) {
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

  Widget _card(List<TripPoint> trimmed) {
    final t = widget.trip;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.episode(t.episode, t.date),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.tripTitle(t.routeName),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpace.x3),
          Row(
            children: [
              RouteBadge('${t.routeId}', size: BadgeSize.sm),
              const SizedBox(width: 9),
              Text(
                '${t.startName} → ${t.endName} · ${t.distanceKm}km',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.x4),
          // 자르고 나서 남는 게 없으면 지도를 그리지 않는다.
          // ⚠ 상자를 **경로 모양에 맞춘다.** 7번 국도처럼 남북으로 긴 길을 넓은 상자에
          //   넣으면 가느다란 선 하나에 좌우가 텅 빈다. 장식을 더하는 대신 여백을 없앤다.
          if (trimmed.length >= 2)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: SizedBox(
                  height: 170,
                  width: 170 * _aspect(trimmed),
                  child: ColoredBox(
                    color: AppColors.fill,
                    child: CustomPaint(painter: _RoutePainter(trimmed)),
                  ),
                ),
              ),
            ),
          if (trimmed.length >= 2) const SizedBox(height: AppSpace.x4),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _chip('${S.statVisited} ${t.visited}', AppColors.tintGreen, AppColors.onTintGreen),
              _chip('${S.statPassed} ${t.passed}', AppColors.fill, AppColors.ink2),
              if (t.skunked > 0)
                _chip('${S.statSkunked} ${t.skunked}번', AppColors.tintSun, AppColors.onTintSun)
              else if (widget.unplannedMeals > 0)
                _chip(
                  '${S.statUnplannedMeal} ${widget.unplannedMeals}',
                  AppColors.tintGreen,
                  AppColors.onTintGreen,
                ),
            ],
          ),
          if (widget.nightSky != null) ...[
            const SizedBox(height: AppSpace.x4),
            Text(
              widget.nightSky!,
              style: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.ink2),
            ),
          ],
          const SizedBox(height: AppSpace.x5),
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          const SizedBox(height: AppSpace.x3),
          Row(
            children: [
              const Text(
                S.appName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.routeBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${S.heroLine1} ${S.heroLine2}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ⚠ width 없는 Container에 alignment를 주면 폭이 최대까지 팽창한다 → Row(min).
  ///   `_statChips`에 같은 주석이 있는데 그대로 밟았다. 골든이 잡았다.
  static Widget _chip(String label, Color bg, Color fg) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 13),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.chip)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
        ),
      ],
    ),
  );
}

/// 지나온 길. **잘라낸 뒤의 점들만** 받는다 — 여기서 다시 자르지 않는다.
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points);
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
  bool shouldRepaint(_RoutePainter old) => old.points != points;
}

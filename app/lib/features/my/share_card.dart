import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
/// **누르면 바로 보낸다** (2026-09-07). 예전엔 카드를 시트로 먼저 띄우고 한 번 더 누르게 했다.
/// 무엇이 나가는지 확인시키려는 의도였는데, 실제로는 같은 버튼을 두 번 누르는 일이 됐다.
///
/// ⚠ 확인을 없앤 대신 **보호는 코드가 한다.** 시작·끝 300m는 `trimEnds`가 언제나 잘라낸다 —
///   사용자가 무엇을 보든 안 보든 집·숙소는 이미지에 들어가지 않는다.
///   무엇이 가려지는지는 버튼 아래 문장으로 계속 적어 둔다 (토스트로 흘리지 않는다).
/// ⚠ 지도는 우리가 그린다. 카카오맵은 플랫폼 뷰라 `RepaintBoundary`에 **안 잡힌다** —
///   캡처하면 빈 자리가 나온다. 실제 GPS 점으로 선을 그리는 게 정확하기도 하다.
Future<void> shareTripCard(
  BuildContext context, {
  required Trip trip,
  required List<TripPoint> path,
  String? nightSky,
  int unplannedMeals = 0,
}) async {
  // 예전 시트의 카드 폭(화면 폭 - 좌우 22)을 그대로 쓴다. 아주 큰 화면에서만 묶는다.
  final width = math.min(MediaQuery.of(context).size.width - 44, 420.0);
  final bytes = await renderCardOffscreen(
    context,
    ShareCard(trip: trip, path: path, nightSky: nightSky, unplannedMeals: unplannedMeals),
    width,
  );
  if (bytes == null) return;

  final file = File('${Directory.systemTemp.path}/ptrip-${trip.id}.png');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: S.tripTitle(trip.routeName)),
  );
}

/// 화면에 띄우지 않고 카드를 PNG로 뜬다.
///
/// ⚠ `Offstage`·`Opacity(0)`은 **아예 그리지 않는다** — 캡처하면 빈 이미지가 나온다.
///   그래서 화면 밖으로 밀어 두되 페인트는 하게 둔다. `RepaintBoundary`는 제 레이어만
///   합성하므로 조상의 클립과 무관하게 온전히 잡힌다.
@visibleForTesting
Future<Uint8List?> renderCardOffscreen(BuildContext context, Widget card, double width) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 0,
      top: 0,
      child: Transform.translate(
        offset: const Offset(-20000, 0),
        child: RepaintBoundary(
          key: key,
          // Material 을 씌워야 기본 텍스트 스타일이 화면과 같아진다.
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(width: width, child: card),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // 붙자마자는 레이아웃도 안 됐다. 실제로 한 번 그려질 때까지 기다린다.
    for (var i = 0; i < 3 && key.currentContext == null; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
    await WidgetsBinding.instance.endOfFrame;
    final obj = key.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    // 3배로 뜬다. 공유된 이미지가 흐리면 카드를 만든 의미가 없다.
    final image = await obj.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}

/// 공유되는 그림 그 자체. 화면에 띄우지 않고 캡처만 한다.
class ShareCard extends StatelessWidget {
  const ShareCard({
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

  /// ⚠ 자르기는 **여기서** 한다. 호출부가 깜빡해도 집·숙소가 새어 나가지 않는다.
  @override
  Widget build(BuildContext context) => _card(trimEnds(path));

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
    final t = trip;
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
              if (t.skunked > 0)
                _chip('${S.statSkunked} ${t.skunked}번', AppColors.tintSun, AppColors.onTintSun)
              else if (unplannedMeals > 0)
                _chip(
                  '${S.statUnplannedMeal} $unplannedMeals',
                  AppColors.tintGreen,
                  AppColors.onTintGreen,
                ),
            ],
          ),
          if (nightSky != null) ...[
            const SizedBox(height: AppSpace.x4),
            Text(
              nightSky!,
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

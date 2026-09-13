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
import '../radar/radar_view.dart';
import 'route_sketch.dart';

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
  int unplannedMeals = 0,
}) async {
  // 예전 시트의 카드 폭(화면 폭 - 좌우 22)을 그대로 쓴다. 아주 큰 화면에서만 묶는다.
  final width = math.min(MediaQuery.of(context).size.width - 44, 420.0);
  final bytes = await renderCardOffscreen(
    context,
    ShareCard(trip: trip, path: path, unplannedMeals: unplannedMeals),
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
  const ShareCard({super.key, required this.trip, required this.path, this.unplannedMeals = 0});

  final Trip trip;
  final List<TripPoint> path;
  final int unplannedMeals;

  /// ⚠ 자르기는 **여기서** 한다. 호출부가 깜빡해도 집·숙소가 새어 나가지 않는다.
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (_, c) => _card(trimEnds(path), c.maxWidth));

  Widget _card(List<TripPoint> trimmed, double cardWidth) {
    final t = trip;
    final visited = [
      for (final s in t.stops)
        if (s.kind == StopKind.visited) s,
    ];
    final hasEnds = t.startName.isNotEmpty && t.endName.isNotEmpty;
    // 지도는 카드 폭을 다 쓰고 4:3 (2026-09-13). 170pt 세로 상자에 구겨 넣던 걸 폈다.
    final sketchW = math.max(120.0, cardWidth - 40);
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
              Expanded(
                child: Text(
                  hasEnds
                      ? '${t.startName} → ${t.endName} · ${t.distanceKm}km'
                      : S.shareMeta(t.routeLabel, t.distanceKm, t.startedAt, t.endedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.x4),
          // 자르고 나서 남는 게 없으면 지도를 그리지 않는다.
          // ⚠ 상자는 카드 폭 그대로 4:3 (2026-09-13). 전에는 높이 170 × 경로 비율이라 남북 길이면
          //   105×170 세로 상자가 됐고, 그 안에서 여백까지 빼면 선이 45pt 폭에 구겨졌다.
          if (trimmed.length >= 2)
            RouteSketch(
              points: trimmed,
              height: sketchW * 0.75,
              width: sketchW,
              // 카드엔 제 머리글이 있어 상자 안 거리·뱃지는 끈다. 점·이름·눈금은 같다.
              stops: t.stops,
              startName: t.startName,
              endName: t.endName,
              startedAt: t.startedAt,
              endedAt: t.endedAt,
              header: false,
            ),
          if (trimmed.length >= 2) const SizedBox(height: AppSpace.x4),
          // 들른 곳 전부 — 번호·이름·시각. 지도의 번호 점과 같은 순서다.
          // 지도 위 이름표는 자리가 있을 때만 붙으니, 이름은 **여기서** 빠짐없이 읽힌다.
          if (visited.isNotEmpty) _stopList(visited),
          if (visited.isNotEmpty) const SizedBox(height: AppSpace.x4),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _chip('${S.statVisited} ${t.visited}', AppColors.tintGreen, AppColors.onTintGreen),
              // 허탕 칩은 뺐다 (2026-09-13) — 남에게 보내는 한 장에 실패 횟수를 적을 이유가 없다.
              if (unplannedMeals > 0)
                _chip(
                  '${S.statUnplannedMeal} $unplannedMeals',
                  AppColors.tintGreen,
                  AppColors.onTintGreen,
                ),
            ],
          ),
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

  /// 2열 목록. 홀수면 마지막 오른쪽 칸은 비운다.
  static Widget _stopList(List<TripStop> visited) => Column(
    children: [
      for (var i = 0; i < visited.length; i += 2)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
          child: Row(
            children: [
              Expanded(child: _stopRow(i + 1, visited[i])),
              const SizedBox(width: 14),
              Expanded(
                child: i + 1 < visited.length ? _stopRow(i + 2, visited[i + 1]) : const SizedBox(),
              ),
            ],
          ),
        ),
    ],
  );

  static Widget _stopRow(int n, TripStop s) => Row(
    children: [
      Container(
        width: 17,
        height: 17,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: radarTypeColors[s.type] ?? AppColors.routeBlue,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$n',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          s.spotName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink2),
        ),
      ),
      if (s.at.isNotEmpty) ...[
        const SizedBox(width: 8),
        Text(
          s.at,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.ink3),
        ),
      ],
    ],
  );

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

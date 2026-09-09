import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';
import 'radar_view.dart';

/// DR-01 「오늘 들른 곳」 자취 (2026-09-09, 시안 A).
///
/// 현재 여행에서 「들르기」를 누른 곳이 들른 순서대로 사진 원으로 이어진다.
/// 테두리는 레이더 블립과 같은 유형색 — 위 그림과 한 벌로 읽힌다. 가장 최근이 오른쪽.
/// ⚠ **기록이지 버튼이 아니다.** 눌러도 아무 일 없다.
/// ⚠ 들른 곳이 없으면 이 위젯을 아예 그리지 않는다 — 빈 칸을 남기지 않는다 (호출부 책임).
/// ⚠ 맨 끝 「다음」 점선 원은 자취가 이어진다는 뜻이지 재촉이 아니다 (원칙 6).
class StopsTrail extends StatefulWidget {
  const StopsTrail({super.key, required this.stops});

  /// 들른 순서대로. `kind == visited` 만 넘길 것.
  final List<TripStop> stops;

  @override
  State<StopsTrail> createState() => _StopsTrailState();
}

class _StopsTrailState extends State<StopsTrail> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(StopsTrail old) {
    super.didUpdateWidget(old);
    // 새로 들렀으면 그 원이 보이게 끝으로 민다.
    if (widget.stops.length > old.stops.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                S.radarStopsTitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.darkInk3,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${stops.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkInk,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 76,
          child: ListView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              for (var i = 0; i < stops.length; i++)
                _StopItem(stop: stops[i], first: i == 0, latest: i == stops.length - 1),
              const _NextItem(),
            ],
          ),
        ),
      ],
    );
  }
}

const _itemW = 74.0;
const _gap = 14.0;
const _circle = 46.0;

class _StopItem extends StatelessWidget {
  const _StopItem({required this.stop, required this.first, required this.latest});
  final TripStop stop;
  final bool first;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final color = radarTypeColors[stop.type] ?? AppColors.routeBlue;
    return SizedBox(
      width: _itemW + _gap,
      child: Stack(
        children: [
          // 점선은 원 **뒤**에 있다. 첫 원은 가운데부터 시작한다.
          Positioned.fill(
            child: CustomPaint(painter: _DashPainter(fromCenter: first)),
          ),
          Column(
            children: [
              Container(
                width: _circle + 6,
                height: _circle + 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkBg,
                  // 가장 최근 것만 바깥에 옅은 테 하나 더.
                  border: latest
                      ? Border.all(color: AppColors.darkInk.withValues(alpha: 0.35), width: 1.5)
                      : null,
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  padding: const EdgeInsets.all(1),
                  child: ClipOval(
                    child: SpotImage(
                      type: stop.type,
                      spotId: stop.spotId,
                      width: _circle - 6,
                      height: _circle - 6,
                      radius: (_circle - 6) / 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: _itemW,
                child: Text(
                  stop.spotName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkInk,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 맨 끝 「다음」 — 점선 원. 다음 발견이 오면 채워진다.
class _NextItem extends StatelessWidget {
  const _NextItem();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _itemW,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DashPainter(toCenter: true))),
          Column(
            children: [
              SizedBox(
                width: _circle + 6,
                height: _circle + 6,
                child: Center(
                  child: CustomPaint(
                    size: const Size(_circle, _circle),
                    painter: _DashedCirclePainter(),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                S.radarStopsNext,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkInk3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 원 높이의 가운데를 지나는 가로 점선.
class _DashPainter extends CustomPainter {
  _DashPainter({this.fromCenter = false, this.toCenter = false});
  final bool fromCenter;
  final bool toCenter;

  @override
  void paint(Canvas canvas, Size size) {
    final y = (_circle + 6) / 2;
    final paint = Paint()
      ..color = AppColors.darkInk.withValues(alpha: 0.22)
      ..strokeWidth = 1.5;
    final start = fromCenter ? _itemW / 2 : 0.0;
    final end = toCenter ? _itemW / 2 : size.width;
    const dash = 4.0;
    const space = 4.0;
    var x = start;
    while (x < end) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(start, end), y), paint);
      x += dash + space;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.fromCenter != fromCenter || old.toCenter != toCenter;
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.darkInk.withValues(alpha: 0.35);
    final r = size.width / 2 - 1;
    final c = Offset(size.width / 2, size.height / 2);
    // 점 24개짜리 원. 배경은 비워 둔다 — 아직 없는 곳이다.
    const n = 24;
    for (var i = 0; i < n; i++) {
      final a0 = i * 2 * 3.141592653589793 / n;
      final a1 = a0 + 3.141592653589793 / n * 0.9;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a0, a1 - a0, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => false;
}

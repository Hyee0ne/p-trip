import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/models.dart';

/// 레이더 뷰 — 동심원 3링 + 회전 스윕 + 블립 (SCREENS.md DR-01).
///
/// ⚠ 경로선을 그리지 않는다. 현재 위치 반경만 보여준다 (CLAUDE.md 원칙 2).
///   목적지가 바뀌어도 이 화면은 아무 반응도 하지 않는다.
class RadarView extends StatefulWidget {
  const RadarView({super.key, required this.blips});

  /// 주변 발견 — 방위와 거리로 배치된다.
  final List<Spot> blips;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: AppMotion.radarSweep,
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (_, _) => CustomPaint(
          painter: _RadarPainter(turn: _sweep.value, blips: widget.blips),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.turn, required this.blips});

  final double turn;
  final List<Spot> blips;

  static const _typeColors = {
    SpotType.market: AppColors.marketRed,
    SpotType.food: AppColors.sun,
    SpotType.view: AppColors.fieldGreen,
    SpotType.culture: AppColors.routeBlue,
    SpotType.stay: AppColors.violet,
    SpotType.camp: AppColors.fieldGreen,
    SpotType.attraction: AppColors.routeBlue,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;

    // 동심원 3링
    final ring = Paint()
      ..color = const Color(0x14F0EDE6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final f in [1.0, 0.68, 0.36]) {
      canvas.drawCircle(c, r * f, ring);
    }

    // 회전 스윕 — 부채꼴 그라데이션
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turn * 2 * math.pi);
    final sweepRect = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawArc(
      sweepRect,
      -math.pi / 2,
      math.pi / 3.4,
      true,
      Paint()
        ..shader = const SweepGradient(
          startAngle: 0,
          endAngle: math.pi / 3.4,
          colors: [Color(0x2E7FBE93), Color(0x007FBE93)],
        ).createShader(sweepRect),
    );
    canvas.restore();

    // 블립 — 유형색으로
    for (var i = 0; i < blips.length; i++) {
      final s = blips[i];
      // 이탈 시간이 멀수록 바깥에 (임시 배치 규칙)
      final dist = (0.34 + (s.detourMin / 14).clamp(0.0, 0.58)) * r;
      final angle = -math.pi / 2 + (i * 2.399); // 황금각으로 고르게 흩는다
      final p = c + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      final col = _typeColors[s.type] ?? AppColors.routeBlue;

      // 오늘성이 있으면 링을 하나 더 둘러 눈에 띄게
      if (s.timeliness != Timeliness.none) {
        canvas.drawCircle(
          p,
          11,
          Paint()
            ..color = col.withValues(alpha: 0.28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      canvas.drawCircle(p, 6, Paint()..color = col);
    }

    // 내 위치
    canvas.drawCircle(
      c,
      13,
      Paint()
        ..color = const Color(0x4D8AA6E0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.drawCircle(c, 6.5, Paint()..color = const Color(0xFF8AA6E0));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.turn != turn || old.blips != blips;
}

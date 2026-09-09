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

/// 레이더 위 유형색. 블립과 「오늘 들른 곳」 자취가 같은 색을 쓴다 — 한 벌로 읽힌다.
const radarTypeColors = {
  SpotType.market: AppColors.marketRed,
  SpotType.food: AppColors.sun,
  SpotType.view: AppColors.fieldGreen,
  SpotType.culture: AppColors.routeBlue,
  SpotType.stay: AppColors.violet,
  SpotType.camp: AppColors.fieldGreen,
  SpotType.attraction: AppColors.routeBlue,
};

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.turn, required this.blips});

  final double turn;
  final List<Spot> blips;

  static const _typeColors = radarTypeColors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;

    // 동심원 3링
    // 링 — 바깥일수록 옅게. 너무 옅으면 계기판으로 안 읽힌다.
    for (final (f, a) in [(1.0, 0x1F), (0.68, 0x2B), (0.36, 0x38)]) {
      canvas.drawCircle(
        c,
        r * f,
        Paint()
          ..color = Color((a << 24) | 0xF0EDE6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    // 십자 기준선 — 방향감
    final axis = Paint()
      ..color = const Color(0x14F0EDE6)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), axis);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), axis);

    // 회전 스윕 — 부채꼴 그라데이션
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turn * 2 * math.pi);
    final sweepRect = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawArc(
      sweepRect,
      -math.pi / 2,
      math.pi / 2.6,
      true,
      Paint()
        ..shader = const SweepGradient(
          startAngle: 0,
          endAngle: math.pi / 2.6,
          colors: [Color(0x8A7FBE93), Color(0x2E7FBE93), Color(0x007FBE93)],
          stops: [0, 0.5, 1],
        ).createShader(sweepRect),
    );
    // 스윕 앞날 — 지금 훑는 지점을 또렷하게
    canvas.drawLine(
      Offset.zero,
      Offset(0, -r),
      Paint()
        ..color = const Color(0x8C9FD8B0)
        ..strokeWidth = 1.6,
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
      canvas.drawCircle(p, 6.5, Paint()..color = col);
      canvas.drawCircle(
        p,
        6.5,
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      // 이름표 — 점만 있으면 뭐가 뭔지 모른다
      final tp = TextPainter(
        text: TextSpan(
          text: s.name,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xD9F0EDE6),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.36);

      // 라벨은 블립 오른쪽이 기본. 오른쪽에 자리가 없으면 왼쪽으로 넘긴다.
      // ⚠ clamp만 쓰면 가장자리에서 블립 위로 올라타 겹친다.
      const gap = 11.0;
      final fitsRight = p.dx + gap + tp.width <= size.width - 2;
      final lx = fitsRight ? p.dx + gap : p.dx - gap - tp.width;
      final ly = (p.dy - tp.height / 2).clamp(2.0, size.height - tp.height - 2);

      // 어두운 받침 — 링·스윕 위에서도 읽히게
      final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(lx - 5, ly - 3, tp.width + 10, tp.height + 6),
        const Radius.circular(6),
      );
      canvas.drawRRect(bg, Paint()..color = const Color(0x8C0F0C09));
      tp.paint(canvas, Offset(lx, ly));
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

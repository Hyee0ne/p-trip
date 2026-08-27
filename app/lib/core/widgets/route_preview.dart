import 'package:flutter/material.dart';
import '../theme.dart';

/// 코스 경로 미리보기.
///
/// ⚠ 지도 SDK를 쓰지 않는다. `kakao_map_plugin` 0.4.0은 M0.5 스파이크에서
/// 아직 검증되지 않았고, 이 화면이 플러그인 때문에 죽으면 안 된다.
/// 실제 지도는 위치를 **골라야 하는** 화면(CO-06 거점 설정)에서만 쓴다.
/// M1에서 course.geom이 들어오면 [points]를 실제 좌표로 그린다.
class RoutePreview extends StatelessWidget {
  const RoutePreview({super.key, required this.routeId, this.height = 150});

  final int routeId;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.hero),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _RoutePainter(), child: const SizedBox.expand()),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F1EE), Color(0xFFDCEAEC), Color(0xFFCFE3E9)],
        ).createShader(rect),
    );

    final path = Path()
      ..moveTo(0, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.26,
        size.height * 0.76,
        size.width * 0.44,
        size.height * 0.58,
      )
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.40, size.width, size.height * 0.14);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );

    // 파선 — 국도 노선
    final dash = Paint()
      ..color = AppColors.routeBlue.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + 8).clamp(0, m.length)), dash);
        d += 15;
      }
    }

    // 발견 핀 — 유형색
    const pins = <(double, double, Color)>[
      (0.30, 0.70, AppColors.marketRed),
      (0.55, 0.48, AppColors.sun),
      (0.76, 0.30, AppColors.fieldGreen),
    ];
    for (final (fx, fy, c) in pins) {
      final o = Offset(size.width * fx, size.height * fy);
      canvas.drawCircle(o, 7, Paint()..color = Colors.white);
      canvas.drawCircle(o, 5, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => false;
}

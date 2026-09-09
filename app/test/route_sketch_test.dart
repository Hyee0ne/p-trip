import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/my/route_sketch.dart';

/// 포스터의 10km 눈금 — 길이에 맞게 개수가 나온다 (2026-09-09).
void main() {
  test('42km 길엔 눈금 넷, 선을 가로지른다', () {
    final t0 = DateTime(2026, 9, 6, 9, 30);
    final pts = [
      for (var i = 0; i < 28; i++)
        TripPoint(
          37.44 + 0.31 * (i / 27) + 0.012 * math.sin(i / 27 * 6.0),
          129.17 - 0.26 * (i / 27) - 0.02 * math.sin(i / 27 * 4.0),
          t0.add(Duration(minutes: i * 9)),
        ),
    ];
    // 좌표를 그대로 픽셀로 (테스트라 축척은 상관없다).
    final lines = RoutePainter.tickLines(pts, (lat, lng) => Offset(lng * 1000, -lat * 1000));
    expect(lines.length, 4, reason: '약 42km → 10·20·30·40km');
    for (final (a, b) in lines) {
      expect((a - b).distance, closeTo(13, 0.01), reason: '양옆 6.5 씩');
    }
  });

  test('10km 가 안 되면 눈금이 없다', () {
    final t0 = DateTime(2026, 9, 6);
    final pts = [
      TripPoint(37.44, 129.17, t0),
      TripPoint(37.46, 129.16, t0.add(const Duration(minutes: 5))),
    ];
    expect(RoutePainter.tickLines(pts, (lat, lng) => Offset(lng, lat)), isEmpty);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/main.dart';

/// 실제 폰 크기에서 오버플로가 나는지 잡는다.
/// 위젯 테스트 기본 크기(800×600)로는 안 잡히는 깨짐이 여기서 드러난다.
void main() {
  const sizes = {
    'iPhone SE (좁음)': Size(375, 667),
    'iPhone 15': Size(393, 852),
    'Pixel 8 Pro (큼)': Size(448, 998),
  };

  for (final entry in sizes.entries) {
    testWidgets('${entry.key} — 홈 두 모드 오버플로 없음', (tester) async {
      tester.view.physicalSize = entry.value * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: PTripApp()));
      // ⚠ 스토리 덱이 자동으로 넘어가므로 pumpAndSettle을 쓸 수 없다
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(tester.takeException(), isNull, reason: '한 곳씩 모드에서 오버플로');

      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '훑어보기 모드에서 오버플로');

      expect(find.text(S.appName), findsOneWidget);
    });
  }
}

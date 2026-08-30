import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/main.dart';

/// 실제 폰 크기에서 오버플로가 나는지 잡는다. 홈은 이제 지도다 (2026-08-30 재설계).
/// 위젯 테스트 기본 크기(800×600)로는 안 잡히는 깨짐이 여기서 드러난다.
void main() {
  const sizes = {
    'iPhone SE (좁음)': Size(375, 667),
    'iPhone 15': Size(393, 852),
    'Pixel 8 Pro (큼)': Size(448, 998),
  };

  for (final entry in sizes.entries) {
    testWidgets('${entry.key} — 홈(지도) 오버플로 없음', (tester) async {
      tester.view.physicalSize = entry.value * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: PTripApp()));
      // ⚠ 지도 화면은 계속 그려서 pumpAndSettle이 끝나지 않는다.
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(tester.takeException(), isNull, reason: '홈 오버플로');

      // 상단바가 없어진 대신 로고 뱃지와 검색창이 지도 위에 뜬다.
      expect(find.text(S.appName), findsOneWidget);
      expect(find.text(S.searchHint), findsOneWidget);

      // 시트를 끝까지 끌어올려도 안 깨지는지
      await tester.drag(find.text(S.routesNearTitle), const Offset(0, -400));
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(tester.takeException(), isNull, reason: '시트 펼침에서 오버플로');
    });
  }
}

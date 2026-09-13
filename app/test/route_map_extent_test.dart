import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/features/discover/route_map.dart';

/// 발견 탭 렉 (2026-09-13): 시트를 끄는 매 프레임 화면 전체가 다시 그려져 AppleMap 이 51선을 다시 보냈다.
/// 시트 높이는 알림자로만 흐른다 — 부모를 다시 그리지 않아도 지도 자리(버튼·'준비 중' 문구)가 따라간다.
void main() {
  testWidgets('시트 높이 알림자만 바꿔도 지도 자리가 따라간다 (부모 rebuild 없이)', (tester) async {
    final extent = ValueNotifier<double>(0.32);
    var parentBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (_) {
            parentBuilds++;
            return SizedBox(
              width: 400,
              height: 800,
              child: RouteMapPanel(fix: null, routes: const [], sheetExtent: extent),
            );
          },
        ),
      ),
    );
    EdgeInsets pad() {
      final c = tester.widget<Container>(
        find.byWidgetPredicate((w) => w is Container && w.padding != null).first,
      );
      return c.padding!.resolve(TextDirection.ltr);
    }

    // 테스트 창이 SizedBox 보다 작으면 창 높이가 기준이다 — 실제 높이로 잰다.
    final h = tester.getSize(find.byType(RouteMapPanel)).height;
    expect(pad().bottom, closeTo(0.32 * h, 0.5));
    extent.value = 0.58;
    await tester.pump();
    expect(pad().bottom, closeTo(0.58 * h, 0.5), reason: '알림자를 듣는 쪽만 다시 그린다');
    expect(parentBuilds, 1, reason: '부모는 한 번만 그려졌다');
    extent.dispose();
  });
}

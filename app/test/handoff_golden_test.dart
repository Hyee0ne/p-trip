import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/base_camp.dart';
import 'package:p_trip/core/theme.dart';
import 'package:p_trip/features/handoff/handoff_sheet.dart';

/// 핸드오프 시트는 **버튼이 셋으로 늘었다** (애플 지도 추가, 2026-09-02 반려 대응).
/// 시트는 탭이 필요해 시뮬레이터로 못 본다 — 골든으로 실물을 뽑는다.
///
/// 갱신: `flutter test --update-goldens test/handoff_golden_test.dart`
void main() {
  setUpAll(() async {
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final f = File('assets/fonts/Pretendard-$w.otf');
      if (!f.existsSync()) continue;
      await (FontLoader(
        'Pretendard',
      )..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
    }
  });

  Future<void> pump(WidgetTester tester, HandoffSheet sheet, String golden, Size size) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          backgroundColor: AppColors.bg,
          body: Align(alignment: Alignment.bottomCenter, child: sheet),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '오버플로');
    await expectLater(find.byType(HandoffSheet), matchesGoldenFile(golden));
  }

  const spot = HandoffPlace('추암 촛대바위', 37.4520, 129.1720);
  const camp = BaseCamp(name: '동해 숙소', lat: 37.5245, lng: 129.1143);

  testWidgets('들르기 — 거점 경유가 있을 때', (tester) async {
    final p = HandoffSheet.visitParams(spot: spot, base: camp, driving: true);
    await pump(
      tester,
      HandoffSheet(mode: HandoffMode.visit, destination: p.destination, via: p.via),
      'goldens/handoff_via.png',
      const Size(393, 852),
    );
  });

  testWidgets('출발 — 경유 없음', (tester) async {
    await pump(
      tester,
      const HandoffSheet(mode: HandoffMode.depart, destination: spot),
      'goldens/handoff_depart.png',
      const Size(393, 852),
    );
  });

  /// 가장 좁은 현역 아이폰. 버튼 둘을 나란히 놓았으니 여기서 안 깨지는지 본다.
  testWidgets('좁은 화면에서도 버튼 둘이 안 깨진다', (tester) async {
    await pump(
      tester,
      const HandoffSheet(mode: HandoffMode.depart, destination: spot),
      'goldens/handoff_small.png',
      const Size(320, 568),
    );
  });
}

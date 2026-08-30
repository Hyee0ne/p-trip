import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/theme.dart';

/// 앱 아이콘 원본(1024x1024).
///
/// 앱의 시그니처는 **국도 표지판 파란 타원 뱃지**다 (CLAUDE.md 디자인 토큰).
/// 숫자 자리에 P를 넣으면 그대로 'P의 여행'이 된다 — 새 모양을 만들지 않았다.
///
/// ⚠ iOS 아이콘은 투명도를 쓰지 않는다. 모서리는 시스템이 깎는다.
/// 갱신: `flutter test --update-goldens test/app_icon_golden_test.dart`
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

  testWidgets('앱 아이콘', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: _Icon()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(_Icon), matchesGoldenFile('goldens/app_icon.png'));
  });
}

class _Icon extends StatelessWidget {
  const _Icon();

  @override
  Widget build(BuildContext context) {
    return Container(
      // 투명 없음 — 꽉 찬 파란 바탕.
      color: AppColors.routeBlue,
      child: Center(
        child: Container(
          width: 620,
          height: 430,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(215)),
          child: const Text(
            'P',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 300,
              fontWeight: FontWeight.w800,
              color: AppColors.routeBlue,
              height: 1.12,
              letterSpacing: -6,
            ),
          ),
        ),
      ),
    );
  }
}

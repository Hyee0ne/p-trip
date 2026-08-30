import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/theme.dart';

/// 공공데이터포털 활용사례 **대표 이미지**(권장 248x93px).
///
/// 앱의 색·서체를 그대로 쓴다 — 따로 디자인 도구를 열 이유가 없고,
/// 토큰이 바뀌면 이 그림도 같이 바뀐다.
///
/// 갱신: `flutter test --update-goldens test/thumbnail_golden_test.dart`
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

  testWidgets('대표 이미지', (tester) async {
    // 248x93을 3배로 떠서 선명하게. 포털 권장 크기의 정수배다.
    tester.view.physicalSize = const Size(248 * 3, 93 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: _Thumb()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(_Thumb), matchesGoldenFile('goldens/thumbnail.png'));
  });
}

class _Thumb extends StatelessWidget {
  const _Thumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // 시그니처 — 국도 표지판 파란 타원 뱃지
          Container(
            width: 34,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.routeBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '7',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  S.appName,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${S.heroLine1} ${S.heroLine2}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 10,
                    color: AppColors.ink2,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

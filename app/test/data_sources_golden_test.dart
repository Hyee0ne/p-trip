import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/theme.dart';
import 'package:p_trip/features/my/data_sources_sheet.dart';

/// 출처 시트는 **라이선스 의무를 이행하는 화면**이라 눈으로 봐야 한다.
/// 시트를 열려면 탭이 필요해 시뮬레이터로는 못 본다 — 골든으로 실물을 뽑는다.
/// (`share_card_golden_test.dart`와 같은 이유다.)
///
/// 갱신: `flutter test --update-goldens test/data_sources_golden_test.dart`
void main() {
  setUpAll(() async {
    // ⚠ 폰트를 안 실으면 글자가 네모로 나온다. 그럼 볼 이유가 없는 그림이다.
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final f = File('assets/fonts/Pretendard-$w.otf');
      if (!f.existsSync()) continue;
      await (FontLoader('Pretendard')
            ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync()))))
          .load();
    }
  });

  Future<void> pumpAt(WidgetTester tester, Size size, String golden) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          backgroundColor: AppColors.bg,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: DataSourcesSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '오버플로');
    await expectLater(find.byType(DataSourcesSheet), matchesGoldenFile(golden));
  }

  /// 보통 화면(iPhone 17)에서는 저작권 문구까지 **한 화면에 다 보여야** 한다.
  testWidgets('데이터 출처 시트 — 전체', (tester) async {
    await pumpAt(tester, const Size(393, 852), 'goldens/data_sources.png');
    expect(find.text('사진과 소개글의 저작권은 각 제공기관에 있습니다.'), findsOneWidget);
  });

  /// 가장 작은 현역 아이폰(SE, 320×568)에서 **넘치지 않아야** 한다.
  /// 처음 만들 때 기본 시트 높이에서 19px 넘쳤다 — 그래서 이 크기로도 잰다.
  testWidgets('데이터 출처 시트 — 작은 화면에서도 안 넘친다', (tester) async {
    await pumpAt(
      tester,
      const Size(320, 568),
      'goldens/data_sources_small.png',
    );
  });
}

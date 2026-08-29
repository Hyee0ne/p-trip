import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/theme.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/my/share_card.dart';

/// 공유 카드는 **다른 사람에게 나가는 유일한 화면**이라 눈으로 봐야 한다.
/// 시트를 열려면 탭이 필요해 시뮬레이터로는 못 본다 — 골든으로 실물을 뽑는다.
///
/// 갱신: `flutter test --update-goldens test/share_card_golden_test.dart`
void main() {
  setUpAll(() async {
    // ⚠ 폰트를 안 실으면 글자가 네모로 나온다. 그럼 볼 이유가 없는 그림이다.
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final f = File('assets/fonts/Pretendard-$w.otf');
      if (!f.existsSync()) continue;
      await (FontLoader(
        'Pretendard',
      )..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
    }
  });

  final t0 = DateTime(2026, 8, 29, 10);
  final path = [
    for (var i = 0; i < 40; i++)
      TripPoint(
        37.4500 + i * 0.0035,
        // 해안선처럼 살짝 굽은 길
        129.1650 - i * 0.0012 + (i % 7) * 0.0004,
        t0.add(Duration(minutes: i * 2)),
      ),
  ];

  final trip = Trip(
    id: 't1',
    episode: 3,
    date: '2026.09.08',
    routeId: 7,
    routeName: '동해 바닷길',
    startName: '삼척',
    endName: '강릉',
    distanceKm: 65,
    startedAt: '10:00',
    endedAt: '17:20',
    photoCount: 0,
    courseId: 'c1',
    stops: const [
      TripStop(
        spotId: 's1',
        spotName: '북평 5일장',
        type: SpotType.market,
        at: '11:20',
        kind: StopKind.visited,
      ),
      TripStop(
        spotId: 's2',
        spotName: '묵호등대',
        type: SpotType.view,
        at: '14:05',
        kind: StopKind.visited,
      ),
      TripStop(
        spotId: 's3',
        spotName: '어달마을',
        type: SpotType.food,
        at: '15:40',
        kind: StopKind.passed,
      ),
    ],
  );

  testWidgets('공유 카드', (tester) async {
    tester.view.physicalSize = const Size(390, 1000) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          backgroundColor: AppColors.bg,
          body: ShareCardSheet(
            trip: trip,
            path: path,
            nightSky: '그날 밤, 달은 없었습니다.',
            unplannedMeals: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '오버플로');
    await expectLater(find.byType(ShareCardSheet), matchesGoldenFile('goldens/share_card.png'));
  });
}

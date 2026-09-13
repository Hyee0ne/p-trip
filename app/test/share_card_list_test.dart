import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/theme.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/my/share_card.dart';

/// 공유 카드 (2026-09-13 실기기): 들른 곳 8개가 105×170 상자에서 서로 겹쳐 구겨졌다.
/// 지도 위 이름표는 자리가 있을 때만 — 대신 **이름은 목록에서 빠짐없이** 읽혀야 한다. 허탕 칩은 없다.
void main() {
  setUpAll(() async {
    // 폰트를 안 실으면 글자가 네모로 나와 이름표 배치를 볼 수 없다.
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final f = File('assets/fonts/Pretendard-$w.otf');
      if (!f.existsSync()) continue;
      await (FontLoader(
        'Pretendard',
      )..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
    }
  });

  final t0 = DateTime(2026, 9, 13, 10, 40);
  // 남북으로 15km, 들른 곳 8개가 한 구간에 몰린 하루.
  final path = [
    for (var i = 0; i < 30; i++)
      TripPoint(37.50 + i * 0.0045, 127.20 + (i % 5) * 0.0006, t0.add(Duration(minutes: i * 8))),
  ];
  final names = ['주렁주렁 하남', '벙커컴퍼니', '강동반상', '일자산 허브천문공원', '위례 신답사', '서울숲 카페 골목길', '은고개', '선답사 카페'];
  final trip = Trip(
    id: 't8',
    episode: 6,
    date: '2026.09.13',
    routeId: 43,
    routeName: '43번 국도',
    startName: '',
    endName: '',
    distanceKm: 15,
    startedAt: '10:40',
    endedAt: '16:10',
    photoCount: 0,
    courseId: '',
    stops: [
      for (var i = 0; i < names.length; i++)
        TripStop(
          spotId: 's$i',
          spotName: names[i],
          type: i.isEven ? SpotType.food : SpotType.view,
          at: '1$i:00',
          kind: StopKind.visited,
          // 한 구간(약 4km)에 몰아 둔다 — 이름표가 다 못 들어가는 상황.
          lat: path[9 + i].lat + (i.isEven ? 0.0008 : -0.0008),
          lng: path[9 + i].lng + (i.isEven ? 0.004 : -0.004),
        ),
      const TripStop(
        spotId: 'x',
        spotName: '문 닫은 집',
        type: SpotType.food,
        at: '13:30',
        kind: StopKind.skunked,
      ),
    ],
  );

  testWidgets('들른 곳 이름은 목록에 전부 나오고, 허탕 칩은 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ShareCard(trip: trip, path: path),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '오버플로');
    for (final n in names) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    expect(find.textContaining(S.statSkunked), findsNothing);
    expect(find.text('43번 국도 · 15km · 10:40–16:10'), findsOneWidget, reason: '지명 없는 국도 출발 머리글');
    expect(find.text('${S.statVisited} 8'), findsOneWidget);
    // 눈으로 볼 것 — 이름표가 못 들어간 점은 번호만, 목록이 이름을 맡는다.
    await expectLater(find.byType(ShareCard), matchesGoldenFile('goldens/share_card_8stops.png'));
  });
}

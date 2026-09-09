import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/trip_log.dart';
import 'package:p_trip/features/my/trip_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MY-02 대표 사진 — 사진첩 선택기로만 고른다 (2026-09-09). 사진 스트립은 지웠다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('여행기 상세 — 「대표 사진」 행과 [사진첩에서 고르기]. 스트립은 없다', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = ProviderContainer();
    addTearDown(c.dispose);
    final log = c.read(tripLogProvider.notifier);
    log.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    log.updateDistance(65);
    final id = log.end()!;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: TripScreen(tripId: id)),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(S.coverTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-pick')), findsOneWidget, reason: '사진첩에서 고르기 버튼');
    expect(find.text(S.coverAuto), findsOneWidget, reason: '아직 안 골랐다');
    expect(find.text('대표'), findsNothing, reason: '스트립도 「대표」 뱃지도 지웠다');
    expect(find.byType(ListView), findsOneWidget, reason: '가로 사진 스트립(ListView)이 없다 — 본문 하나뿐');

    // 사진첩에서 골랐다 치면(선택기는 테스트에 없다) 행이 바뀐다.
    log.setCoverFile(id, 't-1.jpg');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text(S.coverChosen), findsOneWidget);
  });
}

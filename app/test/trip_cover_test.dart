import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/trip_log.dart';
import 'package:p_trip/core/trip_photos.dart';
import 'package:p_trip/features/my/trip_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MY-02 대표 사진 — 사진첩 선택기로만 고른다 (2026-09-09). 스트립 사진은 보기만 한다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('여행기 상세 — 「대표 사진」 행과 [사진첩에서 고르기]. 스트립엔 뱃지가 없다', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = ProviderContainer(
      overrides: [
        tripPhotosProvider.overrideWith(
          (ref, id) async => TripPhotos(
            access: PhotoAccess.granted,
            photos: [
              TripPhoto(
                asset: AssetEntity(id: 'a1', typeInt: 1, width: 100, height: 100),
                at: DateTime(2026, 9, 6, 10, 12),
              ),
            ],
          ),
        ),
      ],
    );
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
    expect(find.text('대표'), findsNothing, reason: '스트립 위 「대표」 뱃지는 지웠다');

    // 사진첩에서 골랐다 치면(선택기는 테스트에 없다) 행이 바뀐다.
    log.setCoverFile(id, 't-1.jpg');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text(S.coverChosen), findsOneWidget);
  });
}

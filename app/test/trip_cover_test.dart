import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/trip_log.dart';
import 'package:p_trip/core/trip_photos.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/my/trip_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MY-02 — 사진 스트립의 사진을 누르면 여행기 대표 사진이 된다 (2026-09-07).
/// 2026-09-09 "바꿀 수 있게 해달라"는 말이 나와 실제로 되는지 테스트로 잠근다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('여행기 상세 — 사진을 누르면 대표 사진이 되고 토스트가 뜬다', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = ProviderContainer(
      overrides: [
        // 사진첩 대신 한 장. AssetEntity 는 껍데기만 — 썸네일 채널은 테스트에 없어 빈 칸으로 그려진다.
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
    log.addStop(
      const Spot(
        id: 's1',
        name: '북평민속오일장',
        type: SpotType.market,
        routeId: 7,
        detourMin: 3,
        trustScore: 90,
      ),
      StopKind.visited,
    );
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
    expect(c.read(tripLogProvider).trips.single.coverPhotoId, '', reason: '고른 적 없다');
    expect(find.byKey(const ValueKey('photo-a1')), findsOneWidget, reason: '내 사진이 스트립에 있다');
    expect(find.byKey(const ValueKey('cover-pick')), findsOneWidget, reason: '사진첩에서 고르기 버튼');
    expect(find.text(S.coverAuto), findsOneWidget, reason: '아직 안 골랐다');

    await tester.tap(find.byKey(const ValueKey('photo-a1')));
    // 화면은 tripProvider(비동기)로 다시 그려진다 — 몇 프레임 준다.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(c.read(tripLogProvider).trips.single.coverPhotoId, 'a1', reason: '누른 사진이 대표가 된다');
    expect(find.text(S.toastCover), findsOneWidget);
    expect(find.text(S.coverBadge), findsOneWidget, reason: '「대표」 뱃지');
    expect(find.text(S.coverChosen), findsOneWidget, reason: '대표 사진 행도 바뀐다');
  });
}

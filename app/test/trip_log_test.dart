import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/saves.dart';
import 'package:p_trip/core/trip_log.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 여행 기록은 **기기 안**에 남는다 (로그인 없음, CLAUDE.md 원칙 5).
/// 주행에서 생기고, 마치면 여행기가 된다.
void main() {
  const spot = Spot(
    id: 'spot-1',
    name: '북평민속오일장',
    type: SpotType.market,
    routeId: 7,
    detourMin: 4,
    trustScore: 85,
  );
  const spot2 = Spot(
    id: 'spot-2',
    name: '추암 촛대바위',
    type: SpotType.view,
    routeId: 7,
    detourMin: 6,
    trustScore: 85,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer make() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  /// ⚠ '스쳐간 곳'(`StopKind.passed`)을 없앴다 (2026-09-07). 옛 기기에는 그 기록이 남아 있다.
  ///   `StopKind.values.firstWhere(..., orElse: visited)` 를 그냥 두면 **지나치기만 한 곳이
  ///   갑자기 '들른 곳'이 된다** — 없앤 기능이 옛 여행기를 거짓으로 만들면 안 된다. 버린다.
  test('옛 기록의 스쳐간 곳은 들른 곳이 되지 않고 사라진다', () async {
    SharedPreferences.setMockInitialValues({
      'trips.v1':
          '[{"id":"t1","episode":1,"date":"2026.08.27","routeId":7,"routeName":"동해 바닷길",'
          '"startName":"삼척","endName":"강릉","distanceKm":65,"startedAt":"09:00",'
          '"endedAt":"18:00","photoCount":0,"points":[],"stops":['
          '{"spotId":"a","spotName":"추암 촛대바위","type":"view","at":"10:00","kind":"visited"},'
          '{"spotId":"b","spotName":"어달해변","type":"view","at":"11:00","kind":"passed"},'
          '{"spotId":"c","spotName":"묵호항","type":"food","at":"12:00","kind":"skunked"}]}]',
    });
    final c = make();
    c.read(tripLogProvider);
    // 복원은 저장소를 여는 비동기다. 이 파일의 다른 테스트와 같은 대기 폭을 쓴다.
    await Future<void>.delayed(const Duration(milliseconds: 40));

    final trip = c.read(tripLogProvider).trips.single;
    expect(trip.stops.map((s) => s.spotId), ['a', 'c'], reason: '스쳐간 곳 b는 버린다');
    expect(trip.visited, 1, reason: 'b가 들른 곳으로 둔갑하면 안 된다');
    expect(trip.skunked, 1);
  });

  /// 여행기 대표 사진은 **내가 그때 찍은 사진**이다 (2026-09-07). 예전엔 언제나
  /// '첫 들른 곳'의 스팟 사진이었다 — 위치와도, 내 사진과도 무관한 그냥 첫 번째였다.
  test('고른 대표 사진은 기기에 남는다', () async {
    final c = make();
    final log = c.read(tripLogProvider.notifier);
    final id = log.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    expect(c.read(tripLogProvider).active!.coverPhotoId, isEmpty, reason: '고르기 전엔 비어 있다');

    log.setCover(id, 'asset-42');
    log.end();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    // 다시 켰을 때도 그대로여야 한다.
    final again = ProviderContainer();
    addTearDown(again.dispose);
    again.read(tripLogProvider);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(again.read(tripLogProvider).trips.single.coverPhotoId, 'asset-42');
  });

  test('출발 → 들르기·허탕 → 마치기', () async {
    final c = make();
    final log = c.read(tripLogProvider.notifier);

    final id = log.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    expect(c.read(tripLogProvider).activeId, id);
    expect(c.read(tripLogProvider).finished, isEmpty, reason: '달리는 중인 여행은 여행기가 아니다');

    log.updateDistance(12.4);
    log.addStop(spot, StopKind.visited);
    log.addStop(spot2, StopKind.skunked);
    log.addStop(spot, StopKind.visited); // 같은 곳을 두 번 담지 않는다

    final active = c.read(tripLogProvider).active!;
    expect(active.distanceKm, 12);
    expect(active.stops.length, 2);
    expect(active.visited, 1);
    expect(active.skunked, 1);

    final ended = log.end();
    expect(ended, id);
    expect(c.read(tripLogProvider).activeId, isNull);
    expect(c.read(tripLogProvider).finished.single.id, id);
    expect(c.read(tripLogProvider).finished.single.endedAt, isNotEmpty);
  });

  test('여행이 둘일 수는 없다 — 달리는 중이면 같은 여행을 이어간다', () {
    final c = make();
    final log = c.read(tripLogProvider.notifier);
    final a = log.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    final b = log.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    expect(a, b);
    expect(c.read(tripLogProvider).trips.length, 1);
  });

  test('앱을 껐다 켜도 여행기가 남는다', () async {
    final first = make();
    final log = first.read(tripLogProvider.notifier);
    log.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    log.updateDistance(65);
    log.addStop(spot, StopKind.visited);
    log.end();
    await Future<void>.delayed(Duration.zero);

    // 새 컨테이너 = 앱 재시작
    final second = make();
    second.read(tripLogProvider);
    await Future<void>.delayed(Duration.zero);
    final trips = second.read(tripLogProvider).finished;
    expect(trips.length, 1, reason: 'SharedPreferences에서 복원돼야 한다');
    expect(trips.single.distanceKm, 65);
    expect(trips.single.stops.single.spotName, '북평민속오일장');
    expect(trips.single.title, '동해 바닷길에서 생긴 일');
  });

  /// 레이더 「오늘 들른 곳」 자취와 여행기 행이 스팟 사진을 쓴다 (2026-09-09).
  test('들른 곳의 대표 사진이 기록에 남고, 없던 옛 기록은 비어 있다', () async {
    const withPhoto = Spot(
      id: 'spot-photo',
      name: '어달해변',
      type: SpotType.view,
      routeId: 7,
      detourMin: 2,
      trustScore: 80,
      imageUrl: 'https://example.com/eodal.jpg',
    );
    final first = make();
    final log = first.read(tripLogProvider.notifier);
    log.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    log.addStop(withPhoto, StopKind.visited);
    log.addStop(spot, StopKind.visited); // 사진 없는 스팟
    log.end();
    await Future<void>.delayed(Duration.zero);

    final second = make();
    second.read(tripLogProvider);
    await Future<void>.delayed(Duration.zero);
    final stops = second.read(tripLogProvider).finished.single.stops;
    expect(stops.first.imageUrl, 'https://example.com/eodal.jpg', reason: '재시작 뒤에도 사진이 남는다');
    expect(stops.last.imageUrl, isNull, reason: '없는 사진을 지어내지 않는다');
  });

  /// 사진첩에서 고른 대표(파일 이름)와 여행 시간대 사진(식별자)은 둘 중 하나만 산다 (2026-09-09).
  test('사진첩 대표 사진은 파일 이름으로 남고, 스트립 대표와 서로 밀어낸다', () async {
    final first = make();
    final log = first.read(tripLogProvider.notifier);
    log.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    log.updateDistance(10);
    final id = log.end()!;
    log.setCover(id, 'asset-1');
    log.setCoverFile(id, 't-123.jpg');
    var trip = first.read(tripLogProvider).finished.single;
    expect(trip.coverPath, 't-123.jpg');
    expect(trip.coverPhotoId, '', reason: '파일을 고르면 식별자는 내려놓는다');
    log.setCover(id, 'asset-2');
    trip = first.read(tripLogProvider).finished.single;
    expect(trip.coverPhotoId, 'asset-2');
    expect(trip.coverPath, '', reason: '스트립을 고르면 파일은 내려놓는다');
    log.setCoverFile(id, 't-456.jpg');
    await Future<void>.delayed(Duration.zero);

    final second = make();
    second.read(tripLogProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      second.read(tripLogProvider).finished.single.coverPath,
      't-456.jpg',
      reason: '재시작 뒤에도 남는다',
    );
  });

  test('저장소가 열리기 전에 찜해도 남는다', () async {
    // ⚠ 앱을 켜자마자 찜하면 SharedPreferences가 아직 안 열려 있다.
    //   그때 쓰기를 버리면 찜이 사라진다 — 실제로 그랬다.
    final first = make();
    first.read(savesProvider.notifier).toggleLike(const SaveRef.spot('bukpyeong'));
    await Future<void>.delayed(Duration.zero);

    final second = make();
    second.read(savesProvider);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(savesProvider).isLiked(const SaveRef.spot('bukpyeong')), isTrue);
  });

  test('강제 종료된 빈 주행은 여행기로 남지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    var c = ProviderContainer();
    c
        .read(tripLogProvider.notifier)
        .start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    // end()를 안 부르고 앱이 죽은 상황.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    c.dispose();

    c = ProviderContainer();
    c.read(tripLogProvider);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(c.read(tripLogProvider).finished, isEmpty, reason: '0km·0곳은 EP가 되면 안 된다');
    c.dispose();
  });

  test('달린 흔적이 있으면 끝맺음이 없어도 남는다', () async {
    SharedPreferences.setMockInitialValues({});
    var c = ProviderContainer();
    final n = c.read(tripLogProvider.notifier);
    n.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    n.updateDistance(12);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    c.dispose();

    c = ProviderContainer();
    c.read(tripLogProvider);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(c.read(tripLogProvider).finished.length, 1);
    expect(c.read(tripLogProvider).finished.first.distanceKm, 12);
    c.dispose();
  });

  test('지나온 경로가 시각과 함께 남는다', () async {
    SharedPreferences.setMockInitialValues({});
    var c = ProviderContainer();
    final n = c.read(tripLogProvider.notifier);
    final id = n.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    n.updateDistance(12);
    n.logPoint(37.4500, 129.1650);
    n.logPoint(37.5000, 129.1400);
    n.end();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    c.dispose();

    // 앱을 껐다 켠다.
    c = ProviderContainer();
    c.read(tripLogProvider);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final pts = c.read(tripLogProvider.notifier).pointsOf(id);

    expect(pts.length, 2, reason: '경로가 저장돼야 사진 매칭·맵매칭을 할 수 있다');
    expect(pts.first.lat, closeTo(37.45, 0.00001));
    expect(pts.first.lng, closeTo(129.165, 0.00001));
    // ⚠ 시각이 좌표만큼 중요하다 — 사진을 경로에 꽂는 기준이다.
    expect(
      pts.first.at.difference(DateTime.now()).abs() < const Duration(minutes: 1),
      isTrue,
      reason: '촬영 시각과 맞춰야 하므로 실제 시각이 남아야 한다',
    );
    expect(pts.last.at.isBefore(pts.first.at), isFalse, reason: '시간 순서대로');
    c.dispose();
  });

  test('버려지는 여행의 경로는 메모리에 싣지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    var c = ProviderContainer();
    final n = c.read(tripLogProvider.notifier);
    // 0km·0곳 — 강제 종료된 빈 주행
    final id = n.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    n.logPoint(37.45, 129.165);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    c.dispose();

    c = ProviderContainer();
    c.read(tripLogProvider);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(c.read(tripLogProvider).finished, isEmpty);
    expect(c.read(tripLogProvider.notifier).pointsOf(id), isEmpty);
    c.dispose();
  });
}

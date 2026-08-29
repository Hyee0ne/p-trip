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

  test('출발 → 들르기·스쳐감 → 마치기', () async {
    final c = make();
    final log = c.read(tripLogProvider.notifier);

    final id = log.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    expect(c.read(tripLogProvider).activeId, id);
    expect(c.read(tripLogProvider).finished, isEmpty, reason: '달리는 중인 여행은 여행기가 아니다');

    log.updateDistance(12.4);
    log.addStop(spot, StopKind.visited);
    log.addStop(spot2, StopKind.passed);
    log.addStop(spot, StopKind.visited); // 같은 곳을 두 번 담지 않는다

    final active = c.read(tripLogProvider).active!;
    expect(active.distanceKm, 12);
    expect(active.stops.length, 2);
    expect(active.visited, 1);
    expect(active.passed, 1);

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
}

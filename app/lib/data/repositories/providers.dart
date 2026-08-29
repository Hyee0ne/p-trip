import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/location.dart';
import '../models/models.dart';
import 'discover_repository.dart';
import 'fixture_discover_repository.dart';
import 'supabase_discover_repository.dart';

/// 실데이터 리포지토리. 키가 없으면 픽스처로 떨어진다.
///
/// ⚠ 픽스처는 지운 게 아니라 **폴백으로 남긴다.** 위젯 테스트가 키 없이 돌아야 하고,
///   네트워크 없는 데서 화면을 확인할 일도 있다.
/// 화면은 [DiscoverRepository] 인터페이스만 보므로 어느 쪽이든 손대지 않는다.
final discoverRepositoryProvider = Provider<DiscoverRepository>(
  (ref) =>
      Env.isConfigured ? const SupabaseDiscoverRepository() : const FixtureDiscoverRepository(),
);

/// CO-07 — 현 위치에서 탈 수 있는 노선. 위치가 없으면 빈 리스트.
final nearbyRoutesProvider = FutureProvider<NearbyResult>((ref) async {
  final fix = await ref.watch(currentLocationProvider.future);
  // 위치를 모르면 '데이터가 없다'가 아니라 '물어볼 수가 없다'다. covered는 참으로 둔다.
  if (!fix.hasFix) return const NearbyResult([], covered: true);
  return ref.watch(discoverRepositoryProvider).nearbyRoutes(lat: fix.lat!, lng: fix.lng!);
});

/// 국도 51선 총 연장. 마이 탭 '완주까지 Nkm'가 이걸 쓴다 —
/// 기획 표기 14,000km를 하드코딩하면 노선이 바뀌어도 안 움직인다.
final totalRoadKmProvider = FutureProvider<int>((ref) async {
  final all = await ref.watch(routesProvider.future);
  return all.fold<int>(0, (a, r) => a + r.totalKm);
});

final routesProvider = FutureProvider<List<RouteLine>>(
  (ref) => ref.watch(discoverRepositoryProvider).routes(),
);

final coursesProvider = FutureProvider.family<List<Course>, int?>(
  (ref, routeId) => ref.watch(discoverRepositoryProvider).courses(routeId: routeId),
);

final axisSpotsProvider = FutureProvider.family<List<Spot>, CurationAxis>(
  (ref, axis) => ref.watch(discoverRepositoryProvider).spots(axis: axis),
);

/// 코스 선형. 모의 주행이 이걸 따라 달린다.
final courseGeometryProvider = FutureProvider.family<List<GeoPoint>, String>(
  (ref, id) => ref.watch(discoverRepositoryProvider).courseGeometry(id),
);

final courseProvider = FutureProvider.family<Course?, String>(
  (ref, id) => ref.watch(discoverRepositoryProvider).course(id),
);

final spotProvider = FutureProvider.family<Spot?, String>(
  (ref, id) => ref.watch(discoverRepositoryProvider).spot(id),
);

final nextVisitsProvider = FutureProvider.family<List<Spot>, String>(
  (ref, spotId) => ref.watch(discoverRepositoryProvider).nextVisits(spotId),
);

typedef SearchArgs = ({String query, bool today, bool near});

final searchProvider = FutureProvider.family<List<Spot>, SearchArgs>(
  (ref, a) =>
      ref.watch(discoverRepositoryProvider).search(a.query, todayOnly: a.today, nearOnly: a.near),
);

/// 코스의 발견들 — spotIds 순서(= 지나는 순서)를 그대로 지킨다.
final courseSpotsProvider = FutureProvider.family<List<Spot>, String>((ref, id) async {
  final repo = ref.watch(discoverRepositoryProvider);
  final c = await repo.course(id);
  if (c == null) return const [];
  final out = <Spot>[];
  for (final sid in c.spotIds) {
    final s = await repo.spot(sid);
    if (s != null) out.add(s);
  }
  return out;
});

/// CO-06 종점 근처 참고 후보 — 숙박·캠핑장. **정보 + 외부 링크까지만**.
final baseCandidatesProvider = FutureProvider<List<Spot>>((ref) async {
  final all = await ref.watch(discoverRepositoryProvider).spots();
  return all.where((s) => s.type == SpotType.stay || s.type == SpotType.camp).toList();
});

final radarQueueProvider = FutureProvider<List<Discovery>>(
  (ref) => ref.watch(discoverRepositoryProvider).radarQueue(),
);

final tripsProvider = FutureProvider<List<Trip>>(
  (ref) => ref.watch(discoverRepositoryProvider).trips(),
);

final tripProvider = FutureProvider.family<Trip?, String>(
  (ref, id) => ref.watch(discoverRepositoryProvider).trip(id),
);

/// 찜·스쳐간 발견 목록 (MY-01).
/// ⚠ `family`의 키는 `==`로 비교된다. **Dart의 `Set`은 값 동등성이 없다** —
///   `{'a'} == {'a'}`가 false다. Set을 키로 쓰면 매 빌드마다 새 provider가 생겨
///   영원히 로딩 상태가 되고(빈 상태 문구조차 안 뜬다) 네트워크도 계속 친다.
///   그래서 정렬해 이어붙인 문자열을 키로 쓴다.
String savedKey(Set<String> ids) => (ids.toList()..sort()).join(',');
Set<String> _parseKey(String key) => key.isEmpty ? const {} : key.split(',').toSet();

final savedSpotsProvider = FutureProvider.family<List<Spot>, String>((ref, key) async {
  final repo = ref.watch(discoverRepositoryProvider);
  final out = <Spot>[];
  for (final id in _parseKey(key)) {
    final s = await repo.spot(id);
    if (s != null) out.add(s);
  }
  return out;
});

final curationDeckProvider = FutureProvider<List<CurationCard>>(
  (ref) => ref.watch(discoverRepositoryProvider).curationDeck(),
);

/// 찜한 코스 (MY-01).
final savedCoursesProvider = FutureProvider.family<List<Course>, String>((ref, key) async {
  final repo = ref.watch(discoverRepositoryProvider);
  final out = <Course>[];
  for (final id in _parseKey(key)) {
    final c = await repo.course(id);
    if (c != null) out.add(c);
  }
  return out;
});

/// 찜한 노선 (MY-01). 코스가 아직 없는 노선의 '출시 알림' 대체다 (SCREENS.md CO-07).
final savedRoutesProvider = FutureProvider.family<List<RouteLine>, String>((ref, key) async {
  // 찜한 노선이 없으면 51선을 통째로 받아올 이유가 없다.
  final ids = _parseKey(key);
  if (ids.isEmpty) return const [];
  final all = await ref.watch(discoverRepositoryProvider).routes();
  return all.where((r) => ids.contains('${r.id}')).toList();
});

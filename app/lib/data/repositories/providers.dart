import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'discover_repository.dart';
import 'fixture_discover_repository.dart';

/// M1 이후 여기 한 줄만 `SupabaseDiscoverRepository()`로 바꾸면 된다.
/// 화면은 [DiscoverRepository] 인터페이스만 보므로 손대지 않는다.
final discoverRepositoryProvider = Provider<DiscoverRepository>(
  (ref) => const FixtureDiscoverRepository(),
);

final routesProvider = FutureProvider<List<RouteLine>>(
  (ref) => ref.watch(discoverRepositoryProvider).routes(),
);

final coursesProvider = FutureProvider.family<List<Course>, int?>(
  (ref, routeId) => ref.watch(discoverRepositoryProvider).courses(routeId: routeId),
);

final axisSpotsProvider = FutureProvider.family<List<Spot>, CurationAxis>(
  (ref, axis) => ref.watch(discoverRepositoryProvider).spots(axis: axis),
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

import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/data/models/models.dart';

/// "계획에 없던 밥" (SCREENS.md MY-02).
///
/// 이 앱이 하려는 일이 이 숫자 하나에 들어 있다 —
/// 정해둔 대로가 아니라 지나다 걸린 곳에서 먹었다는 뜻이다.
void main() {
  TripStop stop(String id, SpotType type, StopKind kind) =>
      TripStop(spotId: id, spotName: id, type: type, at: '12:00', kind: kind);

  Trip trip(List<TripStop> stops, {String courseId = 'c1'}) => Trip(
    id: 't',
    episode: 1,
    date: '2026.08.29',
    routeId: 7,
    routeName: '동해 바닷길',
    startName: '삼척',
    endName: '강릉',
    distanceKm: 65,
    startedAt: '10:00',
    endedAt: '17:00',
    stops: stops,
    photoCount: 0,
    courseId: courseId,
  );

  test('코스에 없던 식당에서 먹으면 센다', () {
    final t = trip([stop('밥집A', SpotType.food, StopKind.visited)]);
    expect(t.unplannedMeals({'코스스팟1'}), 1);
  });

  test('코스에 있던 식당은 계획이었다', () {
    final t = trip([stop('밥집A', SpotType.food, StopKind.visited)]);
    expect(t.unplannedMeals({'밥집A'}), 0);
  });

  test('들르지 않았으면 먹은 게 아니다', () {
    final t = trip([stop('밥집B', SpotType.food, StopKind.skunked)]);
    expect(t.unplannedMeals(const {}), 0);
  });

  test('밥집이 아니면 밥이 아니다', () {
    final t = trip([stop('등대', SpotType.view, StopKind.visited)]);
    expect(t.unplannedMeals(const {}), 0);
  });

  test('코스 없이 달린 여행은 세지 않는다', () {
    // '계획'이 없으면 '계획에 없던'도 없다.
    final t = trip([stop('밥집A', SpotType.food, StopKind.visited)], courseId: '');
    expect(t.unplannedMeals(const {}), 0);
  });
}

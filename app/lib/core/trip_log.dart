import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/models.dart';

/// 여행 기록 — **기기 안에** 남긴다.
///
/// ⚠ 로그인을 넣지 않기로 했다 (CLAUDE.md 원칙 5). 서버의 trips·trip_points 테이블과
///   RLS는 그대로 두고, 계정이 생기는 날 이 로컬 값을 올려 동기화한다.
/// ⚠ 여행기는 본질적으로 그 기기의 기록이다 — 사진도 기기 안 식별자로만 갖는다.
///
/// 저장 형식은 JSON 한 덩어리다. 여행 수가 수십 건 수준이라 DB를 들일 이유가 없다.
class TripLog {
  const TripLog({this.trips = const [], this.activeId});

  final List<Trip> trips;

  /// 지금 달리는 중인 여행. 없으면 null.
  final String? activeId;

  Trip? get active => activeId == null ? null : trips.where((t) => t.id == activeId).firstOrNull;

  /// 끝난 여행만, 최신순. 마이 탭이 이걸 본다.
  List<Trip> get finished => [
    for (final t in trips)
      if (t.id != activeId) t,
  ].reversed.toList();
}

const _kTrips = 'trips.v1';

final tripLogProvider = NotifierProvider<TripLogNotifier, TripLog>(TripLogNotifier.new);

class TripLogNotifier extends Notifier<TripLog> {
  SharedPreferences? _prefs;

  /// 저장소가 열릴 때까지 기다리는 손잡이.
  /// ⚠ 이게 없으면 **앱을 켜자마자 출발한 여행이 안 남는다** — 저장소가 아직 안 열려서
  ///   쓰기가 조용히 버려진다. 테스트가 이걸 잡았다.
  Future<void>? _ready;

  /// 복원 전에 사용자가 먼저 손댔는가. 그러면 복원이 덮어쓰면 안 된다.
  bool _dirty = false;

  /// 여행별 경로. ⚠ 상태에는 안 올린다 — 점 하나 찍을 때마다 화면을 다시 그릴 이유가 없다.
  ///   대신 **저장은 한다.** 사진 매칭(MY-02)과 맵매칭이 이걸 재료로 쓴다.
  final _points = <String, List<TripPoint>>{};

  /// 한 여행이 남길 수 있는 점의 상한. 넘으면 더 안 쌓는다.
  /// ⚠ 폭주 방어용이다 — 정상 주행(0.5km/2분 간격)이면 하루를 달려도 몇백 점이다.
  static const _maxPoints = 5000;

  /// 그 여행이 지나온 길. 없으면 빈 목록 — null을 돌려주지 않는다.
  List<TripPoint> pointsOf(String tripId) => List.unmodifiable(_points[tripId] ?? const []);

  @override
  TripLog build() {
    _ready = _restore();
    return const TripLog();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      final raw = p.getString(_kTrips);
      // 그새 사용자가 출발했으면 복원이 그걸 덮으면 안 된다.
      if (raw == null || _dirty) return;
      final list = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      // ⚠ 앱이 죽으면 달리던 여행은 activeId를 잃고 '끝난 여행'이 된다.
      //   아무것도 안 남긴 주행(0km·들른 곳 0)까지 여행기로 세면 유령 EP가 쌓인다.
      //   뭐라도 남긴 여행은 끝맺음이 없어도 살린다 — 달린 기록을 우리가 지울 수는 없다.
      // ⚠ 한 번씩만 푼다. _fromJson은 경로까지 메모리에 올리는 부작용이 있어
      //   두 번 부르면 버릴 여행의 경로까지 싣게 된다.
      final trips = <Trip>[];
      for (final m in list) {
        final t = _tripFromJson(m);
        if (!_worthKeeping(t)) continue;
        trips.add(t);
        _points[t.id] = _pointsFromJson(m);
      }
      state = TripLog(trips: trips);
    } catch (_) {
      // 저장소를 못 열어도 앱은 돌아야 한다. 이번 실행에만 안 남는다.
    }
  }

  /// 남길 만한 여행인가. 끝맺었으면 무조건 남긴다.
  static bool _worthKeeping(Trip t) =>
      t.endedAt.isNotEmpty || t.distanceKm > 0 || t.stops.isNotEmpty;

  /// ⚠ 저장소가 아직 안 열렸으면 **기다렸다가** 쓴다. 그냥 넘기면 기록이 사라진다.
  Future<void> _persist() async {
    _dirty = true;
    await _ready;
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(_kTrips, jsonEncode([for (final t in state.trips) _toJson(t)]));
  }

  /// 출발. 이미 달리는 중이면 새로 만들지 않는다 — 여행이 둘일 수는 없다.
  String start({
    required int routeId,
    required String routeName,
    required String startName,
    required String endName,
    String courseId = '',
  }) {
    final existing = state.activeId;
    if (existing != null) return existing;

    final now = DateTime.now();
    final id = 'trip-${now.millisecondsSinceEpoch}';
    final trip = Trip(
      id: id,
      episode: state.trips.length + 1,
      date: '${now.year}.${_pad(now.month)}.${_pad(now.day)}',
      routeId: routeId,
      routeName: routeName,
      startName: startName,
      endName: endName,
      distanceKm: 0,
      startedAt: '${_pad(now.hour)}:${_pad(now.minute)}',
      endedAt: '',
      stops: const [],
      photoCount: 0,
      courseId: courseId,
      // 첫 구간 — 여행은 하루, 국도는 구간이다 (DR-08).
      segments: [
        TripSegment(
          routeId: routeId,
          routeName: routeName,
          fromKm: 0,
          at: '${_pad(now.hour)}:${_pad(now.minute)}',
          atEpoch: now.millisecondsSinceEpoch ~/ 1000,
        ),
      ],
    );
    _points[id] = [];
    state = TripLog(trips: [...state.trips, trip], activeId: id);
    unawaited(_persist());
    return id;
  }

  /// GPS 로그. ⚠ 상태를 갈지 않는다 — 점 하나마다 화면을 다시 그릴 이유가 없다.
  void logPoint(double lat, double lng) {
    final id = state.activeId;
    if (id == null) return;
    final list = _points[id] ??= [];
    if (list.length >= _maxPoints) return;
    // 소수점 5자리 ≈ 1m. 그보다 정밀할 이유가 없고 저장만 커진다.
    list.add(
      TripPoint(
        double.parse(lat.toStringAsFixed(5)),
        double.parse(lng.toStringAsFixed(5)),
        DateTime.now(),
      ),
    );
    // ⚠ 점 하나마다 전체를 다시 쓰지 않는다. 10점(약 5km)마다 — 앱이 죽어도
    //   잃는 건 마지막 몇 km고, end()에서 어차피 한 번 더 쓴다.
    if (list.length % 10 == 0) unawaited(_persist());
  }

  /// 들른 곳·허탕. 같은 스팟을 두 번 담지 않는다.
  void addStop(Spot spot, StopKind kind) {
    final trip = state.active;
    if (trip == null) return;
    if (trip.stops.any((s) => s.spotId == spot.id)) return;

    final now = DateTime.now();
    final stop = TripStop(
      spotId: spot.id,
      spotName: spot.name,
      type: spot.type,
      at: '${_pad(now.hour)}:${_pad(now.minute)}',
      kind: kind,
      lat: spot.lat,
      lng: spot.lng,
      imageUrl: spot.imageUrl,
    );
    _replace(trip.id, (t) => _copy(t, stops: [...t.stops, stop]));
  }

  /// 주행 거리 갱신. 여행기의 'Nkm 달림'과 마이 탭 51선 진행률이 이걸 쓴다.
  /// 여행 중 다른 국도로 갈아탄다 (DR-08). 여행은 그대로, 구간만 는다.
  /// 같은 국도면 아무 일도 없다. [atKm] 은 갈아탄 시점의 누적 주행거리.
  void switchRoute({required int routeId, required String routeName, required double atKm}) {
    final id = state.activeId;
    if (id == null) return;
    final t = state.trips.firstWhere((x) => x.id == id);
    final segs = t.segmentsOrSelf;
    if (segs.last.routeId == routeId) return;
    final now = DateTime.now();
    final seg = TripSegment(
      routeId: routeId,
      routeName: routeName,
      fromKm: atKm,
      at: '${_pad(now.hour)}:${_pad(now.minute)}',
      atEpoch: now.millisecondsSinceEpoch ~/ 1000,
    );
    _replace(id, (x) => _copy(x, segments: [...segs, seg]));
  }

  void updateDistance(double km) {
    final trip = state.active;
    if (trip == null) return;
    final rounded = km.round();
    if (rounded == trip.distanceKm) return;
    _replace(trip.id, (t) => _copy(t, distanceKm: rounded));
  }

  /// 여행 마치기. 끝난 여행은 다시 열지 않는다.
  String? end() {
    final trip = state.active;
    if (trip == null) return null;
    final now = DateTime.now();
    _replace(trip.id, (t) => _copy(t, endedAt: '${_pad(now.hour)}:${_pad(now.minute)}'));
    state = TripLog(trips: state.trips, activeId: null);
    unawaited(_persist());
    return trip.id;
  }

  /// 맵매칭 결과를 그 여행에 적는다. 비면 아무것도 안 한다 —
  /// 재보니 국도가 없었다면 예전 방식(routeId 통째)을 그대로 두는 게 낫다.
  void setRouteKm(String tripId, Map<int, int> byRoute) {
    if (byRoute.isEmpty) return;
    _replace(tripId, (t) => _copy(t, routeKm: byRoute));
  }

  /// 여행기를 지운다 (MY-01 옆으로 밀기, 2026-09-09). 되돌리기용으로 (여행, 있던 자리)를 돌려준다.
  /// ⚠ 달리는 중인 여행은 지우지 않는다 — 목록엔 끝난 여행만 있으니 올 일도 없다.
  (Trip, int)? delete(String id) {
    if (id == state.activeId) return null;
    final idx = state.trips.indexWhere((t) => t.id == id);
    if (idx < 0) return null;
    final trip = state.trips[idx];
    state = TripLog(trips: [...state.trips]..removeAt(idx), activeId: state.activeId);
    unawaited(_persist());
    return (trip, idx);
  }

  /// 방금 지운 여행을 있던 자리로 되돌린다 (토스트 「되돌리기」).
  void restore(Trip trip, int index) {
    if (state.trips.any((t) => t.id == trip.id)) return;
    final list = [...state.trips];
    list.insert(index.clamp(0, list.length), trip);
    state = TripLog(trips: list, activeId: state.activeId);
    unawaited(_persist());
  }

  /// 사진첩에서 고른 대표 사진 (2026-09-09). [fileName] 은 `covers/` 안의 파일 이름.
  /// ⚠ 스트립 사진을 탭해 고르던 길(`coverPhotoId`)은 지웠다 (같은 날). 옛 기록의 값은
  ///   그대로 보여주되 새로 적지는 않는다 — 여기서 비운다.
  void setCoverFile(String tripId, String fileName) =>
      _replace(tripId, (t) => _copy(t, coverPhotoId: '', coverPath: fileName));

  void _replace(String id, Trip Function(Trip) f) {
    state = TripLog(
      trips: [
        for (final t in state.trips)
          if (t.id == id) f(t) else t,
      ],
      activeId: state.activeId,
    );
    unawaited(_persist());
  }

  // ── 직렬화 ──────────────────────────────────────────────
  static String _pad(int n) => n.toString().padLeft(2, '0');

  static Trip _copy(
    Trip t, {
    int? distanceKm,
    String? endedAt,
    List<TripStop>? stops,
    int? photoCount,
    Map<int, int>? routeKm,
    String? coverPhotoId,
    String? coverPath,
    List<TripSegment>? segments,
  }) => Trip(
    id: t.id,
    episode: t.episode,
    date: t.date,
    routeId: t.routeId,
    routeName: t.routeName,
    startName: t.startName,
    endName: t.endName,
    distanceKm: distanceKm ?? t.distanceKm,
    startedAt: t.startedAt,
    endedAt: endedAt ?? t.endedAt,
    stops: stops ?? t.stops,
    photoCount: photoCount ?? t.photoCount,
    courseId: t.courseId,
    routeKm: routeKm ?? t.routeKm,
    coverPhotoId: coverPhotoId ?? t.coverPhotoId,
    coverPath: coverPath ?? t.coverPath,
    segments: segments ?? t.segments,
  );

  Map<String, dynamic> _toJson(Trip t) => {
    // [위도, 경도, epoch초]. 키 이름을 붙이면 점 하나당 30바이트가 더 든다.
    'points': [
      for (final p in _points[t.id] ?? const <TripPoint>[])
        [p.lat, p.lng, p.at.millisecondsSinceEpoch ~/ 1000],
    ],
    'id': t.id,
    'episode': t.episode,
    'date': t.date,
    'routeId': t.routeId,
    'routeName': t.routeName,
    'startName': t.startName,
    'endName': t.endName,
    'distanceKm': t.distanceKm,
    'startedAt': t.startedAt,
    'endedAt': t.endedAt,
    'photoCount': t.photoCount,
    'courseId': t.courseId,
    'coverPhotoId': t.coverPhotoId,
    'coverPath': t.coverPath,
    'routeKm': {for (final e in t.routeKm.entries) '${e.key}': e.value},
    'segments': [
      for (final s in t.segments)
        {
          'routeId': s.routeId,
          'routeName': s.routeName,
          'fromKm': s.fromKm,
          'at': s.at,
          'atEpoch': s.atEpoch,
        },
    ],
    'stops': [
      for (final s in t.stops)
        {
          'spotId': s.spotId,
          'spotName': s.spotName,
          'type': s.type.name,
          'at': s.at,
          'kind': s.kind.name,
          'lat': s.lat,
          'lng': s.lng,
          'note': s.note,
          if (s.imageUrl != null) 'imageUrl': s.imageUrl,
        },
    ],
  };

  static List<TripPoint> _pointsFromJson(Map<String, dynamic> m) => [
    for (final p in (m['points'] as List<dynamic>? ?? const []).cast<List<dynamic>>())
      TripPoint(
        (p[0] as num).toDouble(),
        (p[1] as num).toDouble(),
        DateTime.fromMillisecondsSinceEpoch((p[2] as num).toInt() * 1000),
      ),
  ];

  static Trip _tripFromJson(Map<String, dynamic> m) => Trip(
    id: m['id'] as String,
    episode: (m['episode'] as num?)?.toInt() ?? 1,
    date: (m['date'] as String?) ?? '',
    routeId: (m['routeId'] as num?)?.toInt() ?? 0,
    routeName: (m['routeName'] as String?) ?? '',
    startName: (m['startName'] as String?) ?? '',
    endName: (m['endName'] as String?) ?? '',
    distanceKm: (m['distanceKm'] as num?)?.toInt() ?? 0,
    startedAt: (m['startedAt'] as String?) ?? '',
    endedAt: (m['endedAt'] as String?) ?? '',
    photoCount: (m['photoCount'] as num?)?.toInt() ?? 0,
    courseId: (m['courseId'] as String?) ?? '',
    coverPhotoId: (m['coverPhotoId'] as String?) ?? '',
    coverPath: (m['coverPath'] as String?) ?? '',
    routeKm: {
      for (final e in (m['routeKm'] as Map<String, dynamic>? ?? const {}).entries)
        if (int.tryParse(e.key) != null) int.parse(e.key): (e.value as num).toInt(),
    },
    // 옛 기록엔 없다 — 비어 있으면 segmentsOrSelf 가 출발 국도 하나로 읽는다.
    segments: [
      for (final s in (m['segments'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
        TripSegment(
          routeId: (s['routeId'] as num?)?.toInt() ?? 0,
          routeName: (s['routeName'] as String?) ?? '',
          fromKm: (s['fromKm'] as num?)?.toDouble() ?? 0,
          at: (s['at'] as String?) ?? '',
          atEpoch: (s['atEpoch'] as num?)?.toInt() ?? 0,
        ),
    ],
    stops: [
      for (final s in (m['stops'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
        // ⚠ 옛 '스쳐간 곳'은 **버린다** (2026-09-07 기능 삭제).
        //   그냥 두면 아래 orElse 가 visited 로 떨어뜨려, 지나치기만 한 곳이
        //   갑자기 '들른 곳'이 된다. 없앤 기능이 옛 여행기를 거짓으로 만들면 안 된다.
        if (s['kind'] != 'passed')
          TripStop(
            spotId: s['spotId'] as String,
            spotName: (s['spotName'] as String?) ?? '',
            type: SpotType.values.firstWhere(
              (e) => e.name == s['type'],
              orElse: () => SpotType.attraction,
            ),
            at: (s['at'] as String?) ?? '',
            lat: (s['lat'] as num?)?.toDouble(),
            lng: (s['lng'] as num?)?.toDouble(),
            kind: StopKind.values.firstWhere(
              (e) => e.name == s['kind'],
              orElse: () => StopKind.visited,
            ),
            note: (s['note'] as String?) ?? '',
            imageUrl: s['imageUrl'] as String?,
          ),
    ],
  );
}

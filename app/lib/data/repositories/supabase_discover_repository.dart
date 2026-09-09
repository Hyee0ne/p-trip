import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'discover_repository.dart';

/// 실데이터 리포지토리 (M1 이후).
///
/// 화면은 [DiscoverRepository]만 보므로, 이 클래스를 끼우는 것으로 픽스처가 실데이터로 바뀐다.
///
/// ⚠ 별점·후기·랭킹을 읽지 않는다 (원칙 3). 스키마에 그런 컬럼이 아예 없다.
/// ⚠ **`.order()`의 기본값은 내림차순이다** (postgrest-dart). 방향을 늘 명시한다 —
///   빼먹으면 "지나는 순서"가 거꾸로 나오는데 화면만 봐서는 알아채기 어렵다.
/// ⚠ 날짜에 따라 달라지는 판정(장날·행사 임박)은 DB의 `spot_cards` 뷰가 한다 —
///   앱 시계와 서버 날짜가 어긋나는 문제를 피한다.
class SupabaseDiscoverRepository implements DiscoverRepository {
  const SupabaseDiscoverRepository();

  SupabaseClient get _db => Supabase.instance.client;

  // ── 노선 ────────────────────────────────────────────────
  @override
  Future<List<RouteLine>> routes() async {
    // 목록에는 선형을 싣지 않는다. 51선 전국 선형은 수 MB다.
    final rows = await _db
        .from('routes')
        .select('id, name, axis, drivable, from_to, total_km')
        .order('id', ascending: true);
    return [for (final r in rows) _route(r)];
  }

  @override
  Future<List<RouteLine>> routeLines() async {
    // 단순화한 전국 선형. 좌표를 안 보낸다 — `_cell` 을 거칠 값이 없다.
    final rows = await _db.rpc('route_lines_all') as List<dynamic>;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        _route(r, paths: _geoJsonPaths(r['geojson'] as String?)),
    ];
  }

  /// 서버로 나가는 좌표는 **언제나 여기를 거쳐 격자로 뭉갠다** (2026-09-07).
  ///
  /// 0.01도 = 위도 1.11km · 경도 0.88km. 이 앱이 좌표를 쓰는 용도는 전부 이보다 굵다 —
  /// 레이더 반경 5km, 국도 탐색 30km, 앞길 선형 120km, 장소 검색은 근접 정렬 힌트다.
  ///
  /// ⚠ **정확한 GPS 좌표는 기기를 떠나지 않는다.** 위치정보 문의(2026-09-07) 답변이
  ///   "사업자가 보유한 다른 정보와 결합해 특정 개인을 식별할 수 있는지"를 기준으로 든다.
  ///   우리는 식별자를 함께 보내지 않고 저장도 안 하지만, **보내는 값 자체를 뭉개면**
  ///   쿼리가 실패해 인프라 로그에 파라미터가 찍히는 최악의 경우에도
  ///   남는 건 한 사람의 위치가 아니라 격자 한 칸이다.
  ///   로그 설정은 우리가 못 바꾼다 — 보내는 값이 우리가 쥔 유일한 손잡이다.
  ///
  /// ⚠ 레이더는 이미 조회 키를 0.01도로 뭉개서 넘긴다(`radar_screen._queueKey`).
  ///   여기서 한 번 더 거쳐도 값이 바뀌지 않는다 — 그게 맞다. **빠짐없이** 거치는 게 요점이다.
  static double _cell(double v) => (v * 100).roundToDouble() / 100;

  @override
  Future<NearbyResult> nearbyRoutes({required double lat, required double lng}) async {
    final rows =
        await _db.rpc(
              'nearby_routes',
              params: {'p_lat': _cell(lat), 'p_lng': _cell(lng), 'p_max_km': 30},
            )
            as List<dynamic>;

    // 노선 선형은 전국이 다 들어와 있다. 비었으면 데이터가 없는 게 아니라
    // 정말로 국도에서 멀리 있는 것이다 — covered는 참으로 둔다.
    return NearbyResult([
      for (final r in rows.cast<Map<String, dynamic>>())
        NearbyRoute(
          _route(r, paths: _geoJsonPaths(r['geojson'] as String?)),
          distanceKm: (r['distance_km'] as num?)?.toDouble(),
        ),
    ], covered: true);
  }

  @override
  Future<bool> hasSpotsNear({required double lat, required double lng, double km = 30}) async {
    // `discover_ahead` 를 방향 없이 부른다 — 전방향 반경 조회가 된다.
    // 한 건만 확인하면 되니 결과는 세지 않고 비었는지만 본다.
    final rows =
        await _db.rpc(
              'discover_ahead',
              params: {'p_lat': _cell(lat), 'p_lng': _cell(lng), 'p_heading': null, 'p_km': km},
            )
            as List<dynamic>;
    return rows.isNotEmpty;
  }

  // ── 스팟 ────────────────────────────────────────────────
  @override
  Future<List<Spot>> spots({CurationAxis? axis, int? routeId}) async {
    var q = _db.from('spot_cards').select();
    if (routeId != null) q = q.eq('route_id', routeId);

    switch (axis) {
      case CurationAxis.today:
        // 오늘 장날이거나, 이번 주에 끝나는 행사가 걸린 곳.
        q = q.or('market_today.is.true,event_end.lte.${_isoDaysLater(7)}');
      case CurationAxis.rising:
        // 이 축은 rising_spots RPC가 답이라 여기서 처리하지 않는다.
        return _risingSpots();
      case CurationAxis.tracks:
        return _risingSpots();
      case null:
        break;
    }
    final rows = await q.order('trust_score', ascending: false).limit(60);
    return [for (final r in rows) _spot(r)];
  }

  @override
  Future<Spot?> spot(String id) async {
    final rows = await _db.from('spot_cards').select().eq('id', id).limit(1);
    return rows.isEmpty ? null : _spot(rows.first);
  }

  @override
  Future<List<Spot>> search(String query, {bool todayOnly = false, bool nearOnly = false}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    var sel = _db.from('spot_cards').select().ilike('name', '%$q%');
    if (todayOnly) sel = sel.eq('market_today', true);
    if (nearOnly) sel = sel.lte('detour_min', 10);
    final rows = await sel.order('trust_score', ascending: false).limit(40);
    return [for (final r in rows) _spot(r)];
  }

  @override
  Future<List<Spot>> nextVisits(String spotId) async {
    // 발자국 — 이 스팟에 들른 차들이 다음에 간 곳. 최근 시점만 본다.
    final links = await _db
        .from('spot_links')
        .select('to_spot_id, rank, base_ym')
        .eq('from_spot_id', spotId)
        .order('base_ym', ascending: false)
        .order('rank', ascending: true)
        .limit(8);
    final ids = {for (final l in links) l['to_spot_id'] as String}.toList();
    if (ids.isEmpty) return const [];
    final rows = await _db.from('spot_cards').select().inFilter('id', ids);
    return [for (final r in rows) _spot(r)];
  }

  /// 순위가 **오른 폭**으로 고른다. 절대순위 상위를 뽑는 게 아니다 (원칙 3).
  Future<List<Spot>> _risingSpots() async {
    final rows = await _db.rpc('rising_spots', params: {'p_limit': 12}) as List<dynamic>;
    final ids = [for (final r in rows) (r as Map<String, dynamic>)['spot_id'] as String];
    if (ids.isEmpty) return const [];
    final spots = await _db.from('spot_cards').select().inFilter('id', ids);
    // RPC가 준 순서(오른 폭)를 지킨다.
    final byId = {for (final s in spots) s['id'] as String: _spot(s)};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  // ── 코스 ────────────────────────────────────────────────
  @override
  Future<List<Course>> courses({int? routeId}) async {
    var q = _db.from('courses').select();
    if (routeId != null) q = q.eq('route_id', routeId);
    final rows = await q.order('created_at', ascending: true);
    return [for (final r in rows) await _course(r)];
  }

  @override
  Future<Course?> course(String id) async {
    final rows = await _db.from('courses').select().eq('id', id).limit(1);
    return rows.isEmpty ? null : await _course(rows.first);
  }

  @override
  Future<List<GeoPoint>> courseGeometry(String id) async {
    final rows = await _db.rpc('course_geojson', params: {'p_id': id}) as List<dynamic>;
    if (rows.isEmpty) return const [];
    final paths = _geoJsonPaths((rows.first as Map<String, dynamic>)['geojson'] as String?);
    return paths.isEmpty ? const [] : paths.first;
  }

  // ── 큐레이션 덱 ─────────────────────────────────────────
  @override
  Future<List<CurationCard>> curationDeck() async {
    final today = await spots(axis: CurationAxis.today);
    final rising = await _risingSpots();
    final courseList = await courses();
    // 코스 표지는 그 코스 위 첫 스팟 사진을 빌린다.
    final coverById = {
      for (final s in [...today, ...rising]) s.id: s.imageUrl,
    };

    // ⚠ 사진 있는 것을 앞에 세운다. 전면 카드는 사진이 없으면 빈 색면이 된다.
    //   인기순 정렬이 아니라 '카드로 쓸 수 있는가'의 문제라 원칙 3에 걸리지 않는다.
    //   사진 없는 스팟을 목록에서 빼지는 않는다 — 순서만 뒤로 민다.
    List<Spot> photoFirst(List<Spot> xs) => [
      ...xs.where((s) => s.hasPhoto),
      ...xs.where((s) => !s.hasPhoto),
    ];

    final deck = <CurationCard>[
      for (final s in photoFirst(today).take(4)) _card(s, CardAccent.today),
      for (final c in courseList.take(2))
        CourseCurationCard(
          course: c,
          // 표지는 코스 위 첫 스팟 사진을 쓴다. 없으면 유형 그라데이션이 자리를 지킨다.
          coverKey: c.spotIds.isEmpty ? '' : c.spotIds.first,
          coverUrl: c.spotIds.isEmpty ? null : coverById[c.spotIds.first],
          kicker: '길 하나를 통째로',
          body: c.blurb,
          meta: '${c.startName}–${c.endName} · ${c.distanceKm}km',
        ),
      for (final s in photoFirst(rising).take(4)) _card(s, CardAccent.tracks),
    ];
    return deck;
  }

  @override
  Future<TodaySky?> todaySky({required double lat, required double lng}) async {
    final rows =
        await _db.rpc('sun_moon_today', params: {'p_lat': _cell(lat), 'p_lng': _cell(lng)})
            as List<dynamic>;
    if (rows.isEmpty) return null;
    final r = rows.first as Map<String, dynamic>;
    String? hm(String k) {
      final v = r[k] as String?;
      return (v == null || v.length < 5) ? null : v.substring(0, 5);
    }

    return TodaySky(sunset: hm('sunset'));
  }

  @override
  Future<List<GeoPoint>> routePathAhead({
    required int routeId,
    required double lat,
    required double lng,
    required bool northOrEast,
    double maxKm = 120,
  }) async {
    final rows =
        await _db.rpc(
              'route_path_ahead',
              params: {
                'p_route_id': routeId,
                'p_lat': _cell(lat),
                'p_lng': _cell(lng),
                'p_north_or_east': northOrEast,
                'p_max_km': maxKm,
              },
            )
            as List<dynamic>;
    if (rows.isEmpty) return const [];
    // 이을 수 있는 조각이 없으면 빈 목록. 없는 길을 지어내지 않는다.
    return _geoJsonPaths(rows.first['geojson'] as String?).expand((p) => p).toList();
  }

  @override
  Future<Map<int, RouteNote>> routeNotes() async {
    final rows = await _db.rpc('route_notes') as List<dynamic>;
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        (r['route_id'] as num).toInt(): RouteNote(switch (r['kind']) {
          'market_today' => RouteNoteKind.marketToday,
          'popular' => RouteNoteKind.popular,
          _ => RouteNoteKind.rising,
        }, (r['spots'] as num?)?.toInt() ?? 0),
    };
  }

  @override
  Future<Map<int, int>> matchRouteKm(List<TripPoint> points) async {
    if (points.length < 2) return const {};
    final rows =
        await _db.rpc(
              'match_route_km',
              params: {
                'p_points': [
                  for (final p in points) [p.lat, p.lng],
                ],
              },
            )
            as List<dynamic>;
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        (r['route_id'] as num).toInt(): ((r['km'] as num?) ?? 0).round(),
    };
  }

  // ── 레이더 ──────────────────────────────────────────────
  @override
  Future<List<Discovery>> radarQueue({
    required double lat,
    required double lng,
    double? headingDeg,
    double km = 5,
  }) async {
    // ⚠ **현 위치 + 진행 방향 반경**이다 (원칙 2). 노선이나 코스를 보지 않는다 —
    //   코스를 벗어나도, 다른 국도로 갈아타도 그대로 돈다.
    //   전엔 exit_frac 순으로 전 DB에서 30건을 집어왔다. 데모 코스(7번)에서만 맞는 구현이라
    //   43번 국도를 달리면 삼척(7번) 스팟이 떴다 (2026-08-30 실기기).
    final rows =
        await _db.rpc(
              'discover_ahead',
              params: {
                'p_lat': _cell(lat),
                'p_lng': _cell(lng),
                'p_heading': headingDeg,
                'p_km': km,
              },
            )
            as List<dynamic>;
    if (rows.isEmpty) return const [];
    final order = [for (final r in rows) (r as Map<String, dynamic>)['id'] as String];

    // 신뢰도 게이트와 우회 10분은 **레이더에만** 건다 (§3.1). 동승자 모드(DR-05)는 안 건다 —
    // 운전자를 방해하는 화면과 훑어보는 화면의 기준이 다르다.
    final spots = await _db
        .from('spot_cards')
        .select()
        .inFilter('id', order)
        .gte('trust_score', 60)
        .lte('detour_min', 10);
    final byId = {for (final s in spots) s['id'] as String: s};

    return [
      // RPC가 준 순서(가까운 순)를 지킨다.
      for (final id in order)
        if (byId[id] != null)
          () {
            final s = _spot(byId[id]!);
            // 타이틀은 **존재형 문구**다. ⚠ 거리 문구를 넣지 않는다 (SCREENS.md DR-02).
            //   상황 칩이 이미 "국도에서 N분"을 말한다 — 타이틀에 또 쓰면 같은 말이 두 번이다.
            final headline = switch (s.timeliness) {
              Timeliness.marketDay => '오늘이 마침 ${s.name}이에요',
              Timeliness.endingSoon => '${s.name}, 이번 주까지예요',
              _ => s.name,
            };
            // 장날형은 다음 장 안내를 본문에 얹는다 (SCREENS.md DR-02 4번).
            final note = s.timeliness == Timeliness.marketDay ? '' : s.timelinessNote;
            return Discovery(
              spot: s,
              headline: headline,
              situation: s.timelinessNote.isEmpty
                  ? '근처에 있어요 · 국도에서 ${s.detourMin}분'
                  : '${s.timelinessNote} · 국도에서 ${s.detourMin}분',
              body: note.isEmpty ? s.blurb : '$note. ${s.blurb}',
            );
          }(),
    ];
  }

  // ── 매핑 ────────────────────────────────────────────────
  RouteLine _route(Map<String, dynamic> r, {List<List<GeoPoint>> paths = const []}) => RouteLine(
    id: r['id'] as int,
    name: (r['name'] as String?) ?? '',
    axis: (r['axis'] as String?) ?? 'NS',
    drivable: (r['drivable'] as bool?) ?? true,
    fromTo: (r['from_to'] as String?) ?? '',
    totalKm: (r['total_km'] as num?)?.round() ?? 0,
    paths: paths,
  );

  Spot _spot(Map<String, dynamic> r) {
    final marketToday = r['market_today'] == true;
    final inDays = (r['market_in_days'] as num?)?.toInt();
    final eventEnd = r['event_end'] as String?;

    var timeliness = Timeliness.none;
    var note = '';
    if (marketToday) {
      timeliness = Timeliness.marketDay;
      note = '오늘 장날';
    } else if (inDays != null && inDays > 0) {
      note = '다음 장은 $inDays일 뒤';
    } else if (eventEnd != null) {
      final left = DateTime.parse(eventEnd).difference(DateTime.now()).inDays;
      if (left <= 7) {
        timeliness = Timeliness.endingSoon;
        note = left <= 0 ? '오늘까지' : '$left일 남음';
      }
    }

    final image = _https(r['image_url'] as String?);
    return Spot(
      id: r['id'] as String,
      name: r['name'] as String,
      type: _type(r['type'] as String?),
      routeId: (r['route_id'] as num?)?.toInt() ?? 0,
      detourMin: (r['detour_min'] as num?)?.toInt() ?? 0,
      trustScore: (r['trust_score'] as num?)?.toInt() ?? 0,
      blurb: _oneLine(r['blurb'] as String?, name: r['name'] as String?),
      timeliness: timeliness,
      timelinessNote: note,
      openHours: r['open_hours'] as String?,
      tel: r['tel'] as String?,
      addr: r['addr'] as String?,
      hasPhoto: image != null && image.isNotEmpty,
      imageUrl: image,
      lat: (r['lat'] as num?)?.toDouble(),
      lng: (r['lng'] as num?)?.toDouble(),
      exitFrac: (r['exit_frac'] as num?)?.toDouble(),
    );
  }

  Future<Course> _course(Map<String, dynamic> r) async {
    // 코스 위 발견 — 지나는 순서대로. 정렬 칩을 두지 않는 이유이기도 하다.
    final onCourse = await _db
        .from('spot_cards')
        .select('id')
        .eq('route_id', r['route_id'])
        .not('exit_frac', 'is', null)
        .gte('trust_score', 60)
        .lte('detour_min', 10)
        .order('exit_frac', ascending: true)
        .limit(12);
    return Course(
      id: r['id'] as String,
      routeId: (r['route_id'] as num).toInt(),
      title: r['title'] as String,
      startName: (r['start_name'] as String?) ?? '',
      endName: (r['end_name'] as String?) ?? '',
      distanceKm: (r['distance_km'] as num?)?.round() ?? 0,
      durationMin: (r['duration_min'] as num?)?.toInt() ?? 0,
      blurb: (r['blurb'] as String?) ?? '',
      spotIds: [for (final s in onCourse) s['id'] as String],
    );
  }

  SpotCurationCard _card(Spot s, CardAccent accent) => SpotCurationCard(
    spot: s,
    kicker: s.timelinessNote.isEmpty ? '국도에서 ${s.detourMin}분' : s.timelinessNote,
    kickerColor: accent,
    body: s.blurb,
    meta: '${s.routeId}번 국도 · 국도에서 ${s.detourMin}분',
    route: '/spot/${s.id}',
  );

  /// TourAPI 사진은 `http://`로 온다. **iOS ATS가 평문 HTTP를 막아 사진이 안 뜬다.**
  /// 같은 호스트가 https로도 주므로 스킴만 올린다 — ATS 예외를 여는 것보다 낫다.
  static String? _https(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.startsWith('http://') ? url.replaceFirst('http://', 'https://') : url;
  }

  /// 개요를 카드 한 줄로 줄인다.
  /// ⚠ 글자 수로 그냥 자르면 "동해는 원"처럼 문장이 중간에 끊긴다.
  ///   문장 끝('다.'·'.'·'!')을 찾아 거기서 자르고, 못 찾으면 어절 경계에서 자른다.
  static String _oneLine(String? raw, {String? name, int max = 70}) {
    final t = (raw ?? '').trim();
    // ⚠ 개요가 이름만 적혀 있는 스팟이 많다. 그대로 두면 카드에 같은 말이 두 번 나온다.
    if (name != null && (t == name.trim() || t.replaceAll(' ', '') == name.replaceAll(' ', ''))) {
      return '';
    }
    if (t.isEmpty || t.length <= max) return t;
    final head = t.substring(0, max);
    final stop = RegExp(r'[.!?]').allMatches(head).lastOrNull;
    if (stop != null && stop.end > max ~/ 3) return head.substring(0, stop.end).trim();
    final space = head.lastIndexOf(' ');
    return '${(space > max ~/ 3 ? head.substring(0, space) : head).trim()}…';
  }

  static SpotType _type(String? v) => switch (v) {
    'market' => SpotType.market,
    'food' => SpotType.food,
    'view' => SpotType.view,
    'culture' => SpotType.culture,
    'stay' => SpotType.stay,
    'camp' => SpotType.camp,
    _ => SpotType.attraction,
  };

  /// GeoJSON(LineString | MultiLineString) → 갈래별 좌표.
  static List<List<GeoPoint>> _geoJsonPaths(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final g = jsonDecode(raw) as Map<String, dynamic>;
      final coords = g['coordinates'] as List<dynamic>;
      List<GeoPoint> line(List<dynamic> pts) => [
        for (final p in pts) GeoPoint((p as List)[1] as double, p[0] as double),
      ];
      return switch (g['type']) {
        'LineString' => [line(coords)],
        'MultiLineString' => [for (final c in coords) line(c as List<dynamic>)],
        _ => const [],
      };
    } catch (_) {
      // 선형을 못 읽으면 그리지 않는다. 억지로 복구하지 않는다.
      return const [];
    }
  }

  static String _isoDaysLater(int days) =>
      DateTime.now().add(Duration(days: days)).toIso8601String().split('T').first;
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import 'env.dart';

/// 주행 상태.
///
/// ⚠ 이건 **내비가 아니다** (원칙 1). 어디로 가라고 말하지 않고, 지금 어디쯤인지만 안다.
///   턴바이턴·경로 재탐색·ETA를 만들지 않는다. 여기서 나오는 건
///   "코스의 몇 %를 지났나"와 "얼마나 달렸나"뿐이다.
class DriveState {
  const DriveState({
    this.running = false,
    this.elapsedSec = 0,
    this.stoppedSec = 0,
    this.lat,
    this.lng,
    this.headingDeg = 0,
    this.speedKmh = 0,
    this.distanceKm = 0,
    this.frac = 0,
    this.courseKm = 0,
  });

  final bool running;

  /// 주행을 시작한 뒤 흐른 실시간(초). 레이더를 먼저 보여줄 틈을 재는 데 쓴다.
  final double elapsedSec;

  /// 멈춰 있은 실시간(초). 정차 3분이 DR-03 몰아보기의 조건이다.
  final double stoppedSec;
  final double? lat;
  final double? lng;

  /// 진행 방향(도, 정북 0). §3.1 방향 필터가 쓴다.
  final double headingDeg;
  final double speedKmh;

  /// 이 주행에서 누적한 거리. 마이 탭 51선 진행률의 재료다.
  final double distanceKm;

  /// 코스 진행률 0~1. 스팟의 `exitFrac`과 비교해 앞에 있는 발견을 고른다.
  final double frac;
  final double courseKm;

  bool get hasFix => lat != null && lng != null;

  /// 지금 속도로 [exitFrac] 지점까지 남은 시간(분).
  /// ⚠ **도착 시각으로 환산하지 않는다.** 카드를 언제 띄울지 정하는 데만 쓴다 (§3.1).
  double minutesTo(double exitFrac) {
    final aheadKm = (exitFrac - frac) * courseKm;
    if (aheadKm <= 0) return -1;
    return aheadKm / math.max(speedKmh, 20) * 60;
  }

  DriveState copyWith({
    bool? running,
    double? elapsedSec,
    double? stoppedSec,
    double? lat,
    double? lng,
    double? headingDeg,
    double? speedKmh,
    double? distanceKm,
    double? frac,
    double? courseKm,
  }) => DriveState(
    running: running ?? this.running,
    elapsedSec: elapsedSec ?? this.elapsedSec,
    stoppedSec: stoppedSec ?? this.stoppedSec,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    headingDeg: headingDeg ?? this.headingDeg,
    speedKmh: speedKmh ?? this.speedKmh,
    distanceKm: distanceKm ?? this.distanceKm,
    frac: frac ?? this.frac,
    courseKm: courseKm ?? this.courseKm,
  );
}

final driveProvider = NotifierProvider<DriveNotifier, DriveState>(DriveNotifier.new);

/// 코스 선형을 따라 달리는 **모의 주행**.
///
/// 왜 필요한가: 레이더·발견 카드·여행기를 손볼 때마다 실제로 차를 몰고 7번 국도에
/// 나갈 수는 없다. 진짜 노선 선형(routes/courses.geom) 위를 걸어서, 앉아서
/// 전체 흐름을 돌려본다.
///
/// ⚠ 좌표를 지어내지 않는다 — DB의 실제 코스 선형을 그대로 따라간다.
///   실주행으로 바꿀 때는 이 클래스만 geolocator 스트림으로 갈아끼우면 된다.
class DriveNotifier extends Notifier<DriveState> {
  Timer? _tick;
  List<GeoPoint> _path = const [];

  /// 구간별 누적 거리(km). 진행률↔거리 변환에 쓴다.
  List<double> _cum = const [];

  /// 시연용 배속. 65km를 실시간으로 달리면 87분이라 아무도 못 기다린다.
  /// ⚠ 너무 빠르면 카드가 스쳐 지나간다 — 3~7분 창이 실시간 1초도 안 된다.
  double _scale = 20;
  double _kmh = 60;

  @override
  DriveState build() {
    ref.onDispose(() => _tick?.cancel());
    return const DriveState();
  }

  /// [path]를 따라 달리기 시작한다. [scale]은 시연 배속(60이면 1초에 1분).
  void start(List<GeoPoint> path, {double kmh = 60, double? scale}) {
    _tick?.cancel();
    if (path.length < 2) return;

    _path = path;
    _kmh = kmh;
    _scale = scale ?? Env.driveScale;
    _cum = [0];
    for (var i = 1; i < path.length; i++) {
      _cum.add(_cum[i - 1] + _distKm(path[i - 1], path[i]));
    }
    final total = _cum.last;
    state = DriveState(
      running: true,
      lat: path.first.lat,
      lng: path.first.lng,
      headingDeg: _bearing(path[0], path[1]),
      speedKmh: kmh,
      courseKm: total,
    );

    const dt = Duration(milliseconds: 250);
    _tick = Timer.periodic(dt, (_) => _step(dt.inMilliseconds / 1000.0));
  }

  void stop() {
    _tick?.cancel();
    _tick = null;
    state = state.copyWith(running: false, speedKmh: 0);
  }

  /// 잠깐 멈춘다 (들른 곳에 도착). 진행률·거리는 그대로 두고 시계만 센다 —
  /// 정차 시간이 DR-03 몰아보기의 조건이다.
  void pause() {
    if (!state.running) return;
    _tick?.cancel();
    state = state.copyWith(running: false, speedKmh: 0, stoppedSec: 0);
    const dt = Duration(milliseconds: 250);
    _tick = Timer.periodic(dt, (_) {
      state = state.copyWith(stoppedSec: state.stoppedSec + dt.inMilliseconds / 1000.0);
    });
  }

  /// 다시 달린다. 멈춰 있던 시간은 잊는다.
  void resume() {
    if (state.running || _path.length < 2) return;
    _tick?.cancel();
    state = state.copyWith(running: true, speedKmh: _kmh, stoppedSec: 0);
    const dt = Duration(milliseconds: 250);
    _tick = Timer.periodic(dt, (_) => _step(dt.inMilliseconds / 1000.0));
  }

  /// 끝까지 갔으면 멈춘다. 되감지 않는다 — 여행은 한 번 끝나면 끝이다.
  void _step(double seconds) {
    final total = _cum.isEmpty ? 0.0 : _cum.last;
    if (total <= 0) return;
    final moved = _kmh / 3600 * seconds * _scale;
    final next = state.distanceKm + moved;

    if (next >= total) {
      final last = _path.last;
      state = state.copyWith(
        distanceKm: total,
        frac: 1,
        lat: last.lat,
        lng: last.lng,
        running: false,
        speedKmh: 0,
      );
      _tick?.cancel();
      _tick = null;
      return;
    }

    final p = _pointAt(next);
    state = state.copyWith(
      elapsedSec: state.elapsedSec + seconds,
      stoppedSec: 0,
      distanceKm: next,
      frac: next / total,
      lat: p.$1.lat,
      lng: p.$1.lng,
      headingDeg: p.$2,
      speedKmh: _kmh,
    );
  }

  /// 누적거리 [km] 지점의 좌표와 진행 방향.
  (GeoPoint, double) _pointAt(double km) {
    var i = 1;
    while (i < _cum.length - 1 && _cum[i] < km) {
      i++;
    }
    final a = _path[i - 1];
    final b = _path[i];
    final segment = _cum[i] - _cum[i - 1];
    final t = segment <= 0 ? 0.0 : ((km - _cum[i - 1]) / segment).clamp(0.0, 1.0);
    return (GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t), _bearing(a, b));
  }

  static double _distKm(GeoPoint a, GeoPoint b) {
    const r = 6371.0;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _bearing(GeoPoint a, GeoPoint b) {
    final dLng = _rad(b.lng - a.lng);
    final y = math.sin(dLng) * math.cos(_rad(b.lat));
    final x =
        math.cos(_rad(a.lat)) * math.sin(_rad(b.lat)) -
        math.sin(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _rad(double d) => d * math.pi / 180;
}

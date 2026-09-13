import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
    this.needsLocation = false,
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

  /// 실주행인데 위치를 못 받는 상태. 화면이 이유를 말하는 데 쓴다 (DR-00).
  /// ⚠ 모의 주행에서는 항상 false다 — 데모는 권한 없이도 돌아야 한다.
  final bool needsLocation;

  bool get hasFix => lat != null && lng != null;

  /// [exitFrac] 지점까지 **앞으로 남은 거리(km)**. 이미 지났으면 −1.
  ///
  /// ⚠ 카드를 언제 띄울지 정하는 데만 쓴다. **도착 시각으로 환산하지 않는다** (원칙 1).
  /// ⚠ 2026-08-30: 노출 기준을 '남은 시간(분)'에서 **거리**로 바꿨다.
  ///   시간 기준은 속도에 따라 창이 늘었다 줄었다 해서, 같은 길을 달려도
  ///   막히면 코앞의 것만 뜨고 뻥 뚫리면 한참 먼 것이 떴다.
  double kmTo(double exitFrac) {
    final aheadKm = (exitFrac - frac) * courseKm;
    return aheadKm <= 0 ? -1 : aheadKm;
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
    bool? needsLocation,
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
    needsLocation: needsLocation ?? this.needsLocation,
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
  StreamSubscription<Position>? _sub;
  List<GeoPoint> _path = const [];

  /// 구간별 누적 거리(km). 진행률↔거리 변환에 쓴다.
  List<double> _cum = const [];

  /// 모의 주행에서 선형을 갈아탄 시점의 누적거리 — 새 선형은 여기서부터 잰다 (DR-08).
  double _demoOffset = 0;

  /// 시연용 배속. 65km를 실시간으로 달리면 87분이라 아무도 못 기다린다.
  /// ⚠ 너무 빠르면 카드가 스쳐 지나간다 — 3~7분 창이 실시간 1초도 안 된다.
  double _scale = 20;
  double _kmh = 60;

  /// 실주행인가(true) 모의 주행인가. 앱을 내렸다 돌아왔을 때 **같은 방식으로** 잇는다.
  bool _live = false;
  bool _wasBackground = false;

  @override
  DriveState build() {
    ref.onDispose(() {
      _tick?.cancel();
      _sub?.cancel();
    });
    return const DriveState();
  }

  /// [path]를 따라 달리기 시작한다. [scale]은 시연 배속(60이면 1초에 1분).
  void start(List<GeoPoint> path, {double kmh = 60, double? scale}) {
    _tick?.cancel();
    if (path.length < 2) return;

    _path = path;
    _live = false;
    _kmh = kmh;
    _scale = scale ?? Env.driveScale;
    _cum = [0];
    for (var i = 1; i < path.length; i++) {
      _cum.add(_cum[i - 1] + _distKm(path[i - 1], path[i]));
    }
    final total = _cum.last;
    _demoOffset = 0;
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

  /// 여행 중 다른 국도로 갈아탄다 (DR-08). **거리·시간은 이어지고 선형만 바뀐다.**
  /// 모의 주행은 새 선형의 첫 점부터 이어서 달리고, 실주행은 진행률 기준만 바꾼다.
  void switchPath(List<GeoPoint> path) {
    if (path.length < 2) return;
    _path = path;
    _cum = [0];
    for (var i = 1; i < path.length; i++) {
      _cum.add(_cum[i - 1] + _distKm(path[i - 1], path[i]));
    }
    if (_live) {
      state = state.copyWith(frac: 0, courseKm: _cum.last);
      return;
    }
    _demoOffset = state.distanceKm;
    state = state.copyWith(
      lat: path.first.lat,
      lng: path.first.lng,
      headingDeg: _bearing(path[0], path[1]),
      frac: 0,
      courseKm: _cum.last,
    );
  }

  void stop() {
    _tick?.cancel();
    _tick = null;
    _sub?.cancel();
    _sub = null;
    state = state.copyWith(running: false, speedKmh: 0);
  }

  /// **실주행.** GPS 스트림을 받아 같은 DriveState를 채운다.
  ///
  /// ⚠ 여기서도 길안내를 하지 않는다 (원칙 1). 코스 선형은 "코스의 몇 %를 지났나"를
  ///   내는 데만 쓴다 — 벗어나도 아무 일도 일어나지 않고, 되돌아가라고 말하지 않는다.
  /// [background]가 true면 앱을 내려도 위치가 계속 온다 (DR-06).
  /// iOS는 서스펜드되면 Dart가 통째로 멈춰서, 이걸 안 켜면 알림이 **한 건도 안 나간다**.
  Future<void> startLive(List<GeoPoint> course, {bool background = false}) async {
    _tick?.cancel();
    _tick = null;
    _sub?.cancel();

    _path = course;
    _live = true;
    _wasBackground = background;
    _resetClock();
    _cum = [0];
    for (var i = 1; i < course.length; i++) {
      _cum.add(_cum[i - 1] + _distKm(course[i - 1], course[i]));
    }
    state = DriveState(running: true, courseKm: _cum.isEmpty ? 0 : _cum.last);

    // ⚠ 권한을 먼저 묻는다. 안 물어보고 스트림을 열면 iOS에서 조용히 아무것도 안 온다.
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = state.copyWith(running: false, needsLocation: true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        state = state.copyWith(running: false, needsLocation: true);
        return;
      }
    } catch (_) {
      state = state.copyWith(running: false, needsLocation: true);
      return;
    }

    try {
      _sub = Geolocator.getPositionStream(locationSettings: _settings(background)).listen(_onFix);
      _startLiveClock();
    } catch (_) {
      // 기기가 못 주면 멈춰 있는다. 좌표를 지어내지 않는다.
      state = state.copyWith(running: false, needsLocation: true);
    }
  }

  /// ⚠ iOS 백그라운드는 **'앱을 사용하는 동안 허용'으로 충분하다.** '항상 허용'을 받지 않는다 —
  ///   대신 파란 표시줄이 뜬다. 달리는 동안만 본다는 우리 문구가 그래야 사실이 된다.
  /// ⚠ `pauseLocationUpdatesAutomatically`를 끄는 이유: iOS가 알아서 멈추면
  ///   신호등 앞에서 레이더가 조용히 죽는다.
  static LocationSettings _settings(bool background) {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        // 10m마다. 더 촘촘히 받아도 화면이 달라지지 않고 배터리만 먹는다.
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        // 차로 이동 중이라는 힌트일 뿐 — 길안내가 아니다 (원칙 1).
        activityType: ActivityType.automotiveNavigation,
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: '레이더가 앞을 살피는 중',
                notificationText: '여행을 마치면 스스로 꺼져요',
                enableWakeLock: true,
              )
            : null,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  GeoPoint? _lastFix;

  /// 실주행 시계. 경과·정차 초는 **벽시계**로 잰다 (2026-09-13 실기기 빌드 14).
  /// ⚠ 전에는 픽스마다 +1 을 했다. `distanceFilter: 10` 이라 픽스는 10m 마다 오고, 티맵이 앞에 있으면
  ///   더 드문드문 온다 — 1.5km 를 달렸는데 "4초 지났다"가 찍혔다. 그래서 카드 간격의 시간 쪽(3분)은
  ///   사실상 안 찼고(거리 쪽만 돌았다), 정차 초는 서 있으면 픽스가 안 와서(10m 를 안 옮기니까) 안 늘었다.
  ///   지금은 1초 시계와 픽스 둘 다 [_clockAt] 부터 지난 **실제 시간**을 더한다.
  DateTime? _clockAt;
  DateTime? _fixAt;

  /// 서 있기 시작한 시각. 정차 초 = 지금 − 이것. 움직이면 null.
  DateTime? _stillSince;

  /// 픽스가 이만큼 안 오면 서 있는 것으로 본다 — 10m 를 8초에 못 갔으면 1.25m/s 밑이다.
  static const _quietSec = 8;

  double _advanceClock(DateTime now) {
    final dt = _clockAt == null ? 0.0 : now.difference(_clockAt!).inMilliseconds / 1000.0;
    _clockAt = now;
    return dt.clamp(0.0, 3600.0);
  }

  void _resetClock() {
    _lastFix = null;
    _clockAt = DateTime.now();
    _fixAt = null;
    _stillSince = null;
  }

  void _startLiveClock() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _liveTick());
  }

  /// 픽스가 없어도 시계는 간다. 서 있으면 픽스가 안 오니까 — 이게 없으면 정차 2분(DR-07)이 영영 안 찬다.
  void _liveTick() {
    if (!state.running) return;
    final now = DateTime.now();
    final dt = _advanceClock(now);
    // 앱이 잠들었다 깬 뒤의 첫 틱(dt 가 큼)은 그동안 뭘 했는지 모른다 — 다음 픽스가 정하게 둔다.
    final quiet = _fixAt != null && now.difference(_fixAt!).inSeconds >= _quietSec;
    if (_stillSince == null && dt < 3 && quiet) _stillSince = _fixAt;
    state = state.copyWith(elapsedSec: state.elapsedSec + dt, stoppedSec: _stoppedSec(now));
  }

  double _stoppedSec(DateTime now) =>
      _stillSince == null ? 0.0 : now.difference(_stillSince!).inMilliseconds / 1000.0;

  /// 서 있는가. ⚠ 속도만 보면 안 된다 (2026-09-13 실기기) — 서 있어도 GPS 속도가 1~2m/s 로 튀어
  ///   `< 0.5` 가 매초 리셋되고, 정차 2분(DR-07)이 영영 안 찼다. 속도가 느리고 **자리도 안 옮겼을 때**
  ///   서 있는 것으로 본다. 속도를 모르면(-1) 자리로만 본다. 4m 는 정차 중 GPS 흔들림 폭이다.
  /// [sinceSec] — 직전 픽스 뒤로 지난 시간. 30초에 12m 흘러온 건 옮긴 게 아니다 (0.4m/s) —
  ///   서 있으면 픽스가 10m 흔들릴 때만 오니, 이걸 안 보면 주차장에서 정차가 매번 0 으로 돌아간다.
  static bool isStill(double speedMps, double movedKm, {double sinceSec = 1}) {
    const slow = 1.5; // m/s ≈ 5.4km/h
    const jitterKm = 0.004;
    final stayed = movedKm < jitterKm || movedKm * 1000 / math.max(sinceSec, 1.0) < slow;
    if (speedMps < 0) return stayed;
    return speedMps < slow && stayed;
  }

  void _onFix(Position p) {
    final here = GeoPoint(p.latitude, p.longitude);
    final now = DateTime.now();
    final moved = _lastFix == null ? 0.0 : _distKm(_lastFix!, here);
    final sinceFix = _fixAt == null ? 1.0 : now.difference(_fixAt!).inMilliseconds / 1000.0;
    _lastFix = here;
    _fixAt = now;
    final dt = _advanceClock(now);
    if (isStill(p.speed, moved, sinceSec: sinceFix)) {
      // 직전 픽스 때부터 여기 있었다.
      _stillSince ??= now.subtract(Duration(milliseconds: (sinceFix * 1000).round()));
    } else {
      _stillSince = null;
    }

    // 코스 위 어디쯤인지 — 가장 가까운 점을 찾아 누적거리 비율로 환산한다.
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < _path.length; i++) {
      final d = _distKm(_path[i], here);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    final total = _cum.isEmpty ? 0.0 : _cum.last;

    state = state.copyWith(
      running: true,
      needsLocation: false,
      lat: p.latitude,
      lng: p.longitude,
      // heading이 없으면(정차) 직전 값을 유지한다 — 0으로 튀면 방향 필터가 엉킨다.
      headingDeg: p.heading >= 0 ? p.heading : state.headingDeg,
      speedKmh: (p.speed * 3.6).clamp(0, 200),
      distanceKm: state.distanceKm + moved,
      // ⚠ 코스에서 500m 넘게 떨어지면 진행률을 갱신하지 않는다.
      //   벗어난 채로 %를 계속 올리면 있지도 않은 진행을 말하게 된다.
      frac: bestD > 0.5 || total <= 0 ? state.frac : _cum[best] / total,
      elapsedSec: state.elapsedSec + dt,
      stoppedSec: _stoppedSec(now),
    );
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
  ///
  /// ⚠ 진행률·거리를 **그대로 이어받는다.** 앱을 내렸다 돌아왔다고 여행이 처음으로
  ///   돌아가면 안 된다 — 달린 만큼은 달린 것이다.
  /// 백그라운드 위치 허용 여부를 **달리는 중에** 바꾼다.
  ///
  /// ⚠ `startLive`가 이 값을 스트림에 굳혀 넣는다. 그래서 주행을 시작한 뒤
  ///   마이 설정에서 「앱을 꺼둬도 알림」을 켜면, 켠 줄 알지만 iOS는 여전히
  ///   백그라운드 위치를 안 준다 — 앱을 내리는 순간 조용히 멈춘다.
  ///   값이 바뀌었을 때만 스트림을 다시 연다.
  void setBackground(bool background) {
    if (!_live || _wasBackground == background) return;
    _wasBackground = background;
    if (!state.running) return;
    _sub?.cancel();
    try {
      _sub = Geolocator.getPositionStream(locationSettings: _settings(background)).listen(_onFix);
    } catch (_) {
      state = state.copyWith(running: false, needsLocation: true);
    }
  }

  void resume() {
    if (state.running || _path.length < 2) return;
    _tick?.cancel();
    if (_live) {
      // 멈춰 있던 시간은 잊는다. 마지막 좌표는 남긴다 — 다음 픽스가 "그동안 얼마나 옮겼나"로
      // 서 있는지 정한다. 기준 시각만 지금으로 — 옛 시각을 두면 첫 틱이 그동안을 정차로 센다.
      _clockAt = DateTime.now();
      _fixAt = _clockAt;
      _stillSince = null;
      state = state.copyWith(running: true, stoppedSec: 0);
      _sub?.cancel();
      try {
        _sub = Geolocator.getPositionStream(
          locationSettings: _settings(_wasBackground),
        ).listen(_onFix);
        _startLiveClock();
      } catch (_) {
        state = state.copyWith(running: false, needsLocation: true);
      }
      return;
    }
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
    // 선형 위 위치는 갈아탄 시점부터 잰다 — 누적거리는 여행 전체다 (DR-08).
    final along = next - _demoOffset;

    if (along >= total) {
      final last = _path.last;
      state = state.copyWith(
        distanceKm: _demoOffset + total,
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

    final p = _pointAt(along);
    state = state.copyWith(
      elapsedSec: state.elapsedSec + seconds,
      stoppedSec: 0,
      distanceKm: next,
      frac: along / total,
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

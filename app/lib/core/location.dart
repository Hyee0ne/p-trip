import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'env.dart';

/// 위치 상태. UI는 이 값만 보고 분기한다 — geolocator를 화면에서 직접 부르지 않는다.
enum LocStatus {
  /// 기기 위치 서비스가 꺼져 있다.
  serviceOff,

  /// 이번엔 거부. 다시 물어볼 수 있다.
  denied,

  /// 영구 거부. 설정으로 보내야 한다.
  deniedForever,

  /// 좌표를 받았다.
  ready,

  /// 플러그인이 없거나(테스트) 시간 초과. 조용히 지도를 전국으로 둔다.
  unavailable,
}

/// 한 번 측정한 좌표.
@immutable
class LocFix {
  const LocFix(this.status, {this.lat, this.lng});

  final LocStatus status;
  final double? lat;
  final double? lng;

  bool get hasFix => lat != null && lng != null;

  // 위치를 켜달라고 말해도 되는 상태 (막지는 않는다 — SCREENS.md CO-07)
  bool get askable =>
      status == LocStatus.denied ||
      status == LocStatus.deniedForever ||
      status == LocStatus.serviceOff;
}

/// 현재 위치 1회 측정.
///
/// ⚠ 스트림이 아니다. CO-07은 "여기서 탈 수 있는 길"만 알면 되고,
/// 계속 따라다니는 건 내비의 문법이다 (CLAUDE.md 원칙 1).
/// 이동 중 추적은 레이더(DR-01)에서만 한다.
final currentLocationProvider = FutureProvider<LocFix>((ref) async {
  // 개발·시연 주입이 있으면 실제 측정을 건너뛴다 (권한 팝업도 안 뜬다).
  final fake = Env.fakeLocation;
  if (fake != null) return LocFix(LocStatus.ready, lat: fake.$1, lng: fake.$2);

  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocFix(LocStatus.serviceOff);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) return const LocFix(LocStatus.denied);
    if (perm == LocationPermission.deniedForever) {
      return const LocFix(LocStatus.deniedForever);
    }
    final pos = await Geolocator.getCurrentPosition(
      // 국도를 고르는 데 미터 정확도는 필요 없다. 빨리 받는 쪽이 낫다.
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return LocFix(LocStatus.ready, lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    // 테스트 환경(MissingPluginException)·시간 초과 모두 여기로 떨어진다.
    return const LocFix(LocStatus.unavailable);
  }
});

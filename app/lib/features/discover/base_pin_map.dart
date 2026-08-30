import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../core/env.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

/// CO-06 거점 지도 — **핀을 직접 찍는다** (SCREENS.md CO-06 4번).
///
/// 그전에는 그라데이션 상자에 핀 아이콘을 올린 **가짜 지도**였다. 안내문이
/// "핀 하나만 찍으면 레이더의 기준점이 됩니다"라고 약속하는데 찍을 수가 없었다.
///
/// ⚠ 원칙 1: 이 지도도 **어디로 갈지 고르는 지도**다. 경로선·ETA를 올리지 않는다.
/// ⚠ 키가 없으면 지도를 그리지 않는다 — 가짜 지도로 때우지 않는다.
class BasePinMap extends StatefulWidget {
  const BasePinMap({super.key, required this.center, required this.picked, required this.onPick});

  /// 처음 보여줄 자리. 보통 현재 위치나 코스 종점.
  final (double lat, double lng)? center;

  /// 지금 찍혀 있는 핀. 후보 목록에서 고른 것도 여기로 들어온다.
  final (double lat, double lng)? picked;

  final void Function(double lat, double lng) onPick;

  @override
  State<BasePinMap> createState() => _BasePinMapState();
}

class _BasePinMapState extends State<BasePinMap> {
  KakaoMapController? _controller;
  Poi? _pin;
  String? _error;

  /// 위치를 모르면 남한 대략 중심. 지도를 안 그리는 것보다는 낫다.
  LatLng get _initial {
    final c = widget.picked ?? widget.center;
    return c == null ? const LatLng(36.5, 127.9) : LatLng(c.$1, c.$2);
  }

  @override
  void didUpdateWidget(BasePinMap old) {
    super.didUpdateWidget(old);
    final p = widget.picked;
    // 후보 목록에서 골랐을 때도 지도가 따라간다 — 지도와 목록이 따로 놀면 안 된다.
    if (p != null && p != old.picked) {
      _controller?.moveCamera(CameraUpdate.newCenterPosition(LatLng(p.$1, p.$2), zoomLevel: 15));
      _drawPin(LatLng(p.$1, p.$2));
    }
  }

  Future<void> _onReady(KakaoMapController c) async {
    _controller = c;
    final p = widget.picked;
    if (p != null) await _drawPin(LatLng(p.$1, p.$2));
  }

  Future<void> _drawPin(LatLng at) async {
    final c = _controller;
    if (c == null) return;
    final icon = await KImage.fromWidget(
      const _Pin(),
      const Size(36, 44),
      context: mounted ? context : null,
    );
    final old = _pin;
    if (old != null) {
      _pin = null;
      await c.labelLayer.removePoi(old);
    }
    _pin = await c.labelLayer.addPoi(at, style: PoiStyle(icon: icon));
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.hasMapKey || _error != null) return const _MapUnavailable();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.hero),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          children: [
            KakaoMap(
              option: KakaoMapOption(
                position: _initial,
                zoomLevel: widget.picked == null ? 11 : 15,
              ),
              onMapReady: _onReady,
              onMapError: (e) {
                if (mounted) setState(() => _error = e.toString());
              },
              // 탭한 자리가 거점이 된다.
              onMapClick: (_, position) {
                _drawPin(position);
                widget.onPick(position.latitude, position.longitude);
              },
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xF0FFFFFF),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  boxShadow: AppShadow.card,
                ),
                child: const Text(
                  S.basePinOnMap,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 거점 핀. 색은 테마 토큰에서 온다.
class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.place, size: 36, color: AppColors.violet));
}

/// 키가 없거나 지도가 실패했을 때. **가짜 지도를 그리지 않는다** —
/// 후보 목록으로도 거점을 정할 수 있으니 길이 막히지는 않는다.
class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) => Container(
    height: 96,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppRadius.hero),
    ),
    child: const Text(S.baseMapUnavailable, style: TextStyle(fontSize: 13, color: AppColors.ink3)),
  );
}

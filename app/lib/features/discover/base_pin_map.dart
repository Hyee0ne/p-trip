import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../core/env.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

/// CO-06 지도 핀 찍기 — **화면을 채우는 별도 화면**으로 연다.
///
/// ⚠ 처음엔 거점 화면의 스크롤 목록 안에 작은 지도를 넣었는데 **자리가 비어 나왔다.**
///   카카오 지도는 네이티브 플랫폼 뷰라 스크롤 안에서 제대로 합성되지 않는다.
///   CO-07은 지도가 화면을 채우는 `Stack`이라 잘 뜬다 — 같은 모양으로 맞췄다.
///
/// ⚠ 핀을 POI로 그리지 않는다. **화면 가운데 십자를 Flutter로 얹고** 지도를 움직여
///   맞추게 한다. 마커 API를 안 쓰는 만큼 실패할 곳이 줄고, 손가락에 가리지도 않는다.
/// ⚠ 원칙 1: 이 지도도 어디로 갈지 고르는 지도다. 경로선·ETA를 올리지 않는다.
class BasePinPicker extends StatefulWidget {
  const BasePinPicker({super.key, this.center});

  /// 처음 보여줄 자리. 없으면 남한 전체.
  final (double lat, double lng)? center;

  /// 고른 좌표를 돌려준다. 취소하면 null.
  static Future<(double, double)?> open(BuildContext context, {(double, double)? center}) {
    return Navigator.of(context).push<(double, double)>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => BasePinPicker(center: center)),
    );
  }

  @override
  State<BasePinPicker> createState() => _BasePinPickerState();
}

class _BasePinPickerState extends State<BasePinPicker> {
  late LatLng _at = widget.center == null
      ? const LatLng(36.5, 127.9)
      : LatLng(widget.center!.$1, widget.center!.$2);
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          S.basePinOnMap,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
        titleSpacing: 0,
      ),
      body: !Env.hasMapKey || _error != null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.gutter),
                child: Text(
                  S.baseMapUnavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.ink2),
                ),
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: KakaoMap(
                    option: KakaoMapOption(
                      position: _at,
                      zoomLevel: widget.center == null ? 11 : 15,
                    ),
                    // 준비가 끝나야 지도가 뜬다. 여기서 할 일은 없지만 필수 인자다.
                    onMapReady: (_) {},
                    onCameraMoveEnd: (pos, _) => _at = pos.position,
                    onMapError: (e) {
                      if (mounted) setState(() => _error = e.toString());
                    },
                  ),
                ),
                // 십자는 지도 위에 얹는다. 지도를 움직여 여기 맞춘다.
                const IgnorePointer(child: Center(child: _Crosshair())),
                Positioned(
                  left: AppSpace.gutter,
                  right: AppSpace.gutter,
                  bottom: 26,
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.violet,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop((_at.latitude, _at.longitude)),
                      child: const Text(
                        S.basePinHere,
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 가운데 십자. 지도가 움직이고 이건 가만히 있는다.
class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.place, size: 40, color: AppColors.violet),
      // 핀 끝이 가리키는 자리를 점으로 표시한다.
      Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.violet),
      ),
      const SizedBox(height: 40),
    ],
  );
}

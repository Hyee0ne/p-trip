import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../core/env.dart';
import '../../core/location.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart' as m;

/// CO-07 지도 자리.
///
/// 카카오 **네이티브 SDK**(kakao_map_sdk)로 그린다 — 2026-08-29 전환.
/// WebView가 아니라 실제 네이티브 렌더링이라 노선 폴리라인을 여러 개 얹어도 견딘다.
/// 키가 없으면 [_MapPending]이 뜬다 — 가짜 지도를 그리지 않는다.
///
/// ⚠ 원칙 1: 이 지도는 **어디로 갈지 고르는 지도**다.
/// 경로선·턴바이턴·ETA를 올리지 않는다. 레이더(DR-01)에는 지도를 두지 않는다.
class RouteMapPanel extends StatefulWidget {
  const RouteMapPanel({
    super.key,
    required this.fix,
    required this.routes,
    required this.bottomInset,
  });

  /// 현재 위치. 없으면 남한 전체를 보여준다.
  final LocFix? fix;

  /// 그릴 노선. `path`가 빈 노선은 무시한다 — 없는 선을 그리지 않는다.
  final List<m.RouteLine> routes;

  /// 시트에 가려지는 높이. 줌·내 위치 버튼을 그 위로 띄운다.
  final double bottomInset;

  @override
  State<RouteMapPanel> createState() => _RouteMapPanelState();
}

/// 남한 대략 중심 — 위치가 없을 때의 기본 시야.
const _koreaCenter = LatLng(36.5, 127.9);

/// 카카오 줌 레벨은 클수록 확대다 (JS SDK와 반대).
const _zoomNear = 13;
const _zoomWhole = 7;

class _RouteMapPanelState extends State<RouteMapPanel> {
  KakaoMapController? _controller;
  Object? _error;

  /// 이미 그린 노선. 같은 선을 두 번 얹지 않는다.
  final _drawn = <int>{};

  /// 현재 위치 마커. 위치가 갱신되면 지우고 다시 찍는다.
  Poi? _me;

  LatLng get _center {
    final f = widget.fix;
    return f != null && f.hasFix ? LatLng(f.lat!, f.lng!) : _koreaCenter;
  }

  bool get _hasFix => widget.fix?.hasFix ?? false;

  @override
  void didUpdateWidget(RouteMapPanel old) {
    super.didUpdateWidget(old);
    // 위치가 늦게 도착하면 그때 카메라를 옮기고 마커를 찍는다.
    if (!old.fix.sameAs(widget.fix) && _hasFix) {
      _moveTo(_center, _zoomNear);
      _markMe();
    }
    if (old.routes.length != widget.routes.length) _drawRoutes();
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.hasMapKey || _error != null) {
      return _MapPending(bottomInset: widget.bottomInset, failed: _error != null);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: KakaoMap(
            option: KakaoMapOption(position: _center, zoomLevel: _hasFix ? _zoomNear : _zoomWhole),
            onMapReady: _onReady,
            // 키가 틀리면 여기로 온다. 조용히 빈 화면을 두지 않는다.
            onMapError: (e) {
              if (mounted) setState(() => _error = e);
            },
          ),
        ),
        Positioned(
          right: AppSpace.x3,
          bottom: widget.bottomInset + AppSpace.x3,
          child: _Controls(
            onZoomIn: () => _controller?.moveCamera(CameraUpdate.zoomIn()),
            onZoomOut: () => _controller?.moveCamera(CameraUpdate.zoomOut()),
            onLocate: _hasFix ? () => _moveTo(_center, _zoomNear) : null,
          ),
        ),
      ],
    );
  }

  Future<void> _onReady(KakaoMapController controller) async {
    _controller = controller;
    // 나침반·축척은 우리 UI와 겹친다. 지도는 조용해야 한다.
    await controller.compass.hide();
    await _markMe();
    await _drawRoutes();
  }

  Future<void> _moveTo(LatLng position, int zoom) async {
    await _controller?.moveCamera(
      CameraUpdate.newCenterPosition(position, zoomLevel: zoom),
      animation: const CameraAnimation(300),
    );
  }

  /// 현재 위치 점. 에셋 대신 위젯을 그려 이미지로 만든다 —
  /// 색이 테마 토큰과 항상 같이 움직인다.
  Future<void> _markMe() async {
    final c = _controller;
    if (c == null || !_hasFix) return;
    final icon = await KImage.fromWidget(
      const _MeDot(),
      const Size(34, 34),
      context: mounted ? context : null,
    );
    // 이미 찍혀 있으면 지우고 다시 찍는다 (위치가 갱신된 경우).
    final old = _me;
    if (old != null) {
      _me = null;
      await c.labelLayer.removePoi(old);
    }
    _me = await c.labelLayer.addPoi(_center, style: PoiStyle(icon: icon));
  }

  /// 노선 선형. M1 `build-routes.ts`가 GeoJSON을 채우기 전에는 그릴 게 없다.
  Future<void> _drawRoutes() async {
    final c = _controller;
    if (c == null) return;
    final style = RouteStyle(AppColors.routeBlue, 6, strokeColor: Colors.white, strokeWidth: 1);
    for (final r in widget.routes) {
      if (r.path.isEmpty || _drawn.contains(r.id)) continue;
      _drawn.add(r.id);
      await c.routeLayer.addRoute(
        [for (final p in r.path) LatLng(p.lat, p.lng)],
        style,
        id: 'route-${r.id}',
      );
    }
  }
}

/// 위치가 실제로 바뀌었는지. 매 프레임 마커를 다시 찍지 않으려고 본다.
extension on LocFix? {
  bool sameAs(LocFix? other) =>
      this?.lat == other?.lat && this?.lng == other?.lng && this?.status == other?.status;
}

/// 현재 위치 점 — 파란 원 + 흰 테두리 + 옅은 헤일로.
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.routeBlue.withValues(alpha: 0.16),
        ),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.routeBlue,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      ),
    );
  }
}

/// 줌 ± / 내 위치. 시트 위로 떠 있다.
class _Controls extends StatelessWidget {
  const _Controls({required this.onZoomIn, required this.onZoomOut, this.onLocate});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback? onLocate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(icon: Icons.add, onTap: onZoomIn, radius: 12),
        const SizedBox(height: AppSpace.x2),
        _btn(icon: Icons.remove, onTap: onZoomOut, radius: 12),
        const SizedBox(height: AppSpace.x2),
        _btn(
          icon: Icons.near_me,
          onTap: onLocate,
          radius: AppRadius.chip,
          tint: onLocate == null ? AppColors.ink3 : AppColors.routeBlue,
        ),
      ],
    );
  }

  Widget _btn({
    required IconData icon,
    required VoidCallback? onTap,
    required double radius,
    Color tint = AppColors.ink,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          width: AppTouch.min,
          height: AppTouch.min,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: AppShadow.card,
            color: AppColors.surface,
          ),
          child: Icon(icon, size: 19, color: tint),
        ),
      ),
    );
  }
}

/// 카카오 키가 없거나 인증에 실패했을 때. 가짜 지도를 그리는 대신 비어 있다고 말한다.
class _MapPending extends StatelessWidget {
  const _MapPending({required this.bottomInset, this.failed = false});
  final double bottomInset;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // 시트가 올라와 지도 자리가 거의 안 남으면 문구를 접는다.
        final free = box.maxHeight - bottomInset;
        return Container(
          color: AppColors.fill,
          padding: EdgeInsets.only(bottom: bottomInset),
          alignment: Alignment.center,
          child: free < 76
              ? const SizedBox.shrink()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 30,
                      color: AppColors.ink3.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: AppSpace.x3),
                    Text(
                      failed ? S.routesMapFailed : S.routesMapPending,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

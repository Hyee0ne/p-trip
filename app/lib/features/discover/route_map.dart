import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import '../../core/env.dart';
import '../../core/location.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';

/// CO-07 지도 자리.
///
/// 카카오 키가 붙기 전에는 [_MapPending]이 뜬다 — 가짜 지도를 그리지 않는다.
/// 키가 들어오면 이 위젯 안에서만 바뀌고 화면(RoutesScreen)은 손대지 않는다.
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
  final List<RouteLine> routes;

  /// 시트에 가려지는 높이. 줌·내 위치 버튼을 그 위로 띄운다.
  final double bottomInset;

  @override
  State<RouteMapPanel> createState() => _RouteMapPanelState();
}

/// 남한 대략 중심 — 위치가 없을 때의 기본 시야.
const _koreaCenter = (lat: 36.5, lng: 127.9);
const _levelNear = 8;
const _levelWhole = 13;

class _RouteMapPanelState extends State<RouteMapPanel> {
  KakaoMapController? _controller;

  /// 보이는 영역. 이 밖의 노선은 그리지 않는다 (WebView 부하 — SCREENS.md CO-07).
  LatLngBounds? _bounds;

  int _level = _levelWhole;

  @override
  Widget build(BuildContext context) {
    if (!Env.hasMapKey) return _MapPending(bottomInset: widget.bottomInset);

    final fix = widget.fix;
    final center = fix != null && fix.hasFix
        ? LatLng(fix.lat!, fix.lng!)
        : LatLng(_koreaCenter.lat, _koreaCenter.lng);

    return Stack(
      children: [
        Positioned.fill(
          child: KakaoMap(
            center: center,
            currentLevel: fix != null && fix.hasFix ? _levelNear : _levelWhole,
            // 줌 컨트롤은 우리가 그린다 — 시트 위로 띄워야 해서 위치를 잡아야 한다.
            zoomControl: false,
            mapTypeControl: false,
            polylines: _visiblePolylines(),
            customOverlays: _overlays(center, fix),
            onMapCreated: (c) => _controller = c,
            onBoundsChangeCallback: (b) => setState(() => _bounds = b),
            onZoomChangeCallback: (level, _) => _level = level,
          ),
        ),
        Positioned(
          right: AppSpace.x3,
          bottom: widget.bottomInset + AppSpace.x3,
          child: _Controls(
            onZoomIn: () => _setLevel(_level - 1),
            onZoomOut: () => _setLevel(_level + 1),
            onLocate: fix != null && fix.hasFix
                ? () {
                    _controller?.panTo(LatLng(fix.lat!, fix.lng!));
                    _setLevel(_levelNear);
                  }
                : null,
          ),
        ),
      ],
    );
  }

  void _setLevel(int level) {
    final clamped = level.clamp(1, 14);
    _level = clamped;
    _controller?.setLevel(clamped);
  }

  /// 보이는 영역에 걸치는 노선만. 51개를 통째로 얹지 않는다.
  List<Polyline> _visiblePolylines() {
    final b = _bounds;
    return [
      for (final r in widget.routes)
        if (r.path.isNotEmpty && _intersects(r.path, b))
          Polyline(
            polylineId: 'route-${r.id}',
            points: [for (final p in r.path) LatLng(p.lat, p.lng)],
            strokeColor: AppColors.routeBlue,
            strokeWidth: 5,
            strokeOpacity: 0.85,
          ),
    ];
  }

  bool _intersects(List<GeoPoint> path, LatLngBounds? b) {
    if (b == null) return true;
    // 화면 밖에서 들어오는 선이 잘려 보이지 않게 여유를 둔다.
    const pad = 0.15;
    final minLat = b.sw.latitude - pad, maxLat = b.ne.latitude + pad;
    final minLng = b.sw.longitude - pad, maxLng = b.ne.longitude + pad;
    for (final p in path) {
      if (p.lat >= minLat && p.lat <= maxLat && p.lng >= minLng && p.lng <= maxLng) {
        return true;
      }
    }
    return false;
  }

  List<CustomOverlay> _overlays(LatLng center, LocFix? fix) => [
    if (fix != null && fix.hasFix)
      CustomOverlay(
        customOverlayId: 'me',
        latLng: center,
        yAnchor: 0.5,
        content:
            '<div style="width:16px;height:16px;border-radius:50%;'
            'background:#1D4ED8;border:3px solid #fff;'
            'box-shadow:0 0 0 7px rgba(29,78,216,.16)"></div>',
      ),
  ];
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

/// 카카오 키가 없을 때. 가짜 지도를 그리는 대신 비어 있다고 말한다.
class _MapPending extends StatelessWidget {
  const _MapPending({required this.bottomInset});
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // 시트가 올라와 지도 자리가 거의 안 남으면 문구를 접는다.
        // 남은 높이에 억지로 밀어 넣으면 오버플로가 난다.
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
                    const Text(
                      S.routesMapPending,
                      style: TextStyle(
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

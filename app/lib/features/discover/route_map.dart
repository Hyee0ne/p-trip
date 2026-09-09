import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/location.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart' as m;

/// CO-07 지도 자리.
///
/// **Apple MapKit**(apple_maps_flutter)으로 그린다 — 2026-09-09 카카오맵에서 교체.
/// 키가 없고, 타일 요청이 OS 제조사(Apple) 밖으로 나가지 않는다. 지난 반려(Guideline 4,
/// "내장 지도와 연결되지 않는다")와도 같은 방향이다. iOS 전용 앱이라 잃는 게 없다.
/// ⚠ iOS 가 아닌 곳(위젯 테스트)에서는 [_MapPending] 이 뜬다 — 가짜 지도를 그리지 않는다.
///
/// ⚠ 원칙 1: 이 지도는 **어디로 갈지 고르는 지도**다.
/// 경로선·턴바이턴·ETA를 올리지 않는다. 레이더(DR-01)에는 지도를 두지 않는다.
class RouteMapPanel extends StatefulWidget {
  const RouteMapPanel({
    super.key,
    required this.fix,
    required this.routes,
    required this.bottomInset,
    this.onRouteTap,
  });

  /// 현재 위치. 없으면 남한 전체를 보여준다.
  final LocFix? fix;

  /// 그릴 노선. `path`가 빈 노선은 무시한다 — 없는 선을 그리지 않는다.
  final List<m.RouteLine> routes;

  /// 시트에 가려지는 높이. 줌·내 위치 버튼을 그 위로 띄운다.
  final double bottomInset;

  /// 지도 위의 파란 선을 눌렀을 때. 그 노선을 돌려준다.
  final void Function(m.RouteLine)? onRouteTap;

  @override
  State<RouteMapPanel> createState() => _RouteMapPanelState();
}

/// 남한 대략 중심 — 위치가 없을 때의 기본 시야.
const _koreaCenter = LatLng(36.5, 127.9);

/// MapKit 줌은 구글식이다 — 클수록 확대. 6.6이면 남한이 한 화면, 13이면 동네.
const _zoomNear = 13.0;
const _zoomWhole = 6.6;

class _RouteMapPanelState extends State<RouteMapPanel> {
  AppleMapController? _controller;

  /// 지금 줌. 손가락 오차를 미터로 환산할 때 쓴다.
  double _zoom = _zoomWhole;

  /// 노선 폴리라인. 노선 목록이 바뀔 때만 다시 만든다 — 매 프레임 51선을 새로 세지 않는다.
  Set<Polyline> _polylines = const {};

  /// 눌린 자리에서 가장 가까운 노선.
  ///
  /// ⚠ 폴리라인 탭 대신 지도 탭 좌표로 찾는다 — 선이 가늘어 정확히 누르기 어렵다.
  /// ⚠ 허용 오차를 **줌에 따라 바꾼다.** 전국이 보이는 화면에서 1km는 1픽셀도 안 되고,
  ///   확대한 화면에서 1km는 화면 절반이다. 고정값을 쓰면 둘 중 하나는 못 쓴다.
  m.RouteLine? _routeAt(LatLng at) {
    // 웹 메르카토르 기준 미터/픽셀. 손가락 반경 24px쯤을 허용한다.
    final mPerPx = 156543.03 * math.cos(at.latitude * math.pi / 180) / math.pow(2, _zoom);
    final tolKm = (mPerPx * 24 / 1000).clamp(0.15, 20.0);

    m.RouteLine? best;
    var bestKm = double.infinity;
    for (final r in widget.routes) {
      for (final chain in r.paths) {
        for (final p in chain) {
          final dx = (p.lng - at.longitude) * 88.0;
          final dy = (p.lat - at.latitude) * 111.0;
          final km = math.sqrt(dx * dx + dy * dy);
          if (km < bestKm) {
            bestKm = km;
            best = r;
          }
        }
      }
    }
    // 멀면 아무것도 안 고른다 — 바다를 눌렀는데 노선이 열리면 안 된다.
    return bestKm <= tolKm ? best : null;
  }

  LatLng get _center {
    final f = widget.fix;
    return f != null && f.hasFix ? LatLng(f.lat!, f.lng!) : _koreaCenter;
  }

  bool get _hasFix => widget.fix?.hasFix ?? false;

  @override
  void initState() {
    super.initState();
    _polylines = _buildPolylines();
  }

  @override
  void didUpdateWidget(RouteMapPanel old) {
    super.didUpdateWidget(old);
    // 위치가 늦게 도착하면 그때 카메라를 옮긴다. 내 위치 점은 MapKit 이 직접 찍는다.
    if (!old.fix.sameAs(widget.fix) && _hasFix) _moveTo(_center, _zoomNear);
    if (!identical(old.routes, widget.routes)) _polylines = _buildPolylines();
  }

  /// 갈래마다 따로 그린다. 국도는 끊겨 있어서 한 줄로 이으면 없는 길이 생긴다.
  /// 흰 밑선 + 파란 선 두 겹 — MapKit 폴리라인엔 테두리가 없어서 이렇게 낸다.
  Set<Polyline> _buildPolylines() {
    final out = <Polyline>{};
    for (final r in widget.routes) {
      for (var i = 0; i < r.paths.length; i++) {
        final chain = r.paths[i];
        if (chain.length < 2) continue;
        final pts = [for (final p in chain) LatLng(p.lat, p.lng)];
        out.add(
          Polyline(
            polylineId: PolylineId('u-${r.id}-$i'),
            points: pts,
            color: Colors.white,
            width: 7,
          ),
        );
        out.add(
          Polyline(
            polylineId: PolylineId('r-${r.id}-$i'),
            points: pts,
            color: AppColors.routeBlue,
            width: 5,
            zIndex: 1,
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return _MapPending(bottomInset: widget.bottomInset);

    return LayoutBuilder(
      builder: (context, box) {
        // 시트를 끝까지 올리면 지도가 손가락 두 마디만 남는다. 그 위에 버튼 셋을 얹으면 상태바를 뚫는다.
        final showControls = box.maxHeight - widget.bottomInset >= 200;
        return Stack(
          children: [
            Positioned.fill(
              child: AppleMap(
                initialCameraPosition: CameraPosition(
                  target: _center,
                  zoom: _hasFix ? _zoomNear : _zoomWhole,
                ),
                onMapCreated: (c) => _controller = c,
                onCameraMove: (pos) => _zoom = pos.zoom,
                // 나침반·내 위치 버튼은 우리 UI와 겹친다. 지도는 조용해야 한다.
                compassEnabled: false,
                myLocationEnabled: _hasFix,
                myLocationButtonEnabled: false,
                pitchGesturesEnabled: false,
                rotateGesturesEnabled: false,
                polylines: _polylines,
                onTap: widget.onRouteTap == null
                    ? null
                    : (at) {
                        final r = _routeAt(at);
                        if (r != null) widget.onRouteTap!(r);
                      },
              ),
            ),
            if (showControls)
              Positioned(
                right: AppSpace.x3,
                bottom: widget.bottomInset + AppSpace.x3,
                child: _Controls(
                  onZoomIn: () => _controller?.animateCamera(CameraUpdate.zoomIn()),
                  onZoomOut: () => _controller?.animateCamera(CameraUpdate.zoomOut()),
                  onLocate: _hasFix ? () => _moveTo(_center, _zoomNear) : null,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _moveTo(LatLng position, double zoom) async {
    await _controller?.animateCamera(CameraUpdate.newLatLngZoom(position, zoom));
  }
}

/// 위치가 실제로 바뀌었는지. 매 프레임 카메라를 옮기지 않으려고 본다.
extension on LocFix? {
  bool sameAs(LocFix? other) =>
      this?.lat == other?.lat && this?.lng == other?.lng && this?.status == other?.status;
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

/// iOS 가 아닐 때(위젯 테스트·macOS). 가짜 지도를 그리는 대신 비어 있다고 말한다.
class _MapPending extends StatelessWidget {
  const _MapPending({required this.bottomInset});
  final double bottomInset;

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
                    const Text(
                      S.routesMapPending,
                      textAlign: TextAlign.center,
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

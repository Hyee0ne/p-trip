import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/foundation.dart';
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
    required this.sheetExtent,
    this.onRouteTap,
    this.focus,
    this.selectedId,
  });

  /// 고른 노선으로 카메라를 옮기는 요청. null 이면 아무것도 안 한다.
  final MapFocus? focus;

  /// 지금 고른 노선. **노란색**으로 맨 위에 그린다 — 지도가 움직인 뒤 "어디"가 보여야 한다 (2026-09-09).
  final int? selectedId;

  /// 현재 위치. 없으면 남한 전체를 보여준다.
  final LocFix? fix;

  /// 그릴 노선 — **51선 전부** (단순화 선형). `paths`가 빈 노선은 무시한다.
  final List<m.RouteLine> routes;

  /// 시트가 덮는 비율(0~1)의 알림자. 줌·내 위치 버튼을 그 위로 띄운다.
  /// ⚠ 매 프레임 바뀌지만 **지도는 다시 그리지 않는다** — 듣는 건 버튼 자리뿐이다 (2026-09-13).
  final ValueListenable<double> sheetExtent;

  /// 지도 위의 파란 선을 눌렀을 때. 그 노선을 돌려준다.
  final void Function(m.RouteLine)? onRouteTap;

  @override
  State<RouteMapPanel> createState() => _RouteMapPanelState();
}

/// 노선을 골랐을 때 지도가 그 길로 가는 요청 (2026-09-09).
///
/// [seq] 가 바뀔 때마다 한 번 움직인다 — 같은 길을 다시 골라도 다시 간다.
/// [visibleFraction] 은 시트에 가려지지 않은 화면 비율. 길이 그 안에 들어오게 남쪽을 늘려 맞춘다.
class MapFocus {
  const MapFocus(this.routeId, this.seq, this.visibleFraction);
  final int routeId;
  final int seq;
  final double visibleFraction;
}

/// 남한 대략 중심 — 위치가 없을 때의 기본 시야.
const _koreaCenter = LatLng(36.5, 127.9);

/// MapKit 줌은 구글식이다 — 클수록 확대. 6.6이면 남한이 한 화면, 13이면 동네.
const _zoomNear = 13.0;
const _zoomWhole = 6.6;

class _RouteMapPanelState extends State<RouteMapPanel> {
  AppleMapController? _controller;

  /// 지도 위젯 **인스턴스**를 들고 있는다 (2026-09-13 발견 탭 렉).
  ///
  /// apple_maps_flutter 는 `didUpdateWidget` 마다 폴리라인 **전부**를 '바뀐 것'으로 플랫폼에 다시 보낸다
  /// (`_PolylineUpdates.from` — 같은 id 는 무조건 change, 점 비교를 안 한다). 51선 1만 점이 부모가
  /// 다시 그려질 때마다 채널을 건넜다. 같은 인스턴스를 넘기면 Flutter 가 그 서브트리 갱신을 건너뛴다.
  /// 선·마커가 바뀔 때만 [_remap] 으로 새로 만든다.
  Widget? _map;

  /// 지금 줌. 손가락 오차를 미터로 환산할 때 쓴다.
  double _zoom = _zoomWhole;

  /// 노선 폴리라인. 노선 목록이 바뀔 때만 다시 만든다 — 시트를 끄는 매 프레임에
  /// 51선 수만 점을 새로 세지 않는다.
  Set<Polyline> _polylines = const {};

  /// 현재 위치 마커. **우리가 그린다** — MapKit 의 파란 점(`showsUserLocation`)은 실기기에서
  /// 안 보였다 (2026-09-09). 한 번 잰 위치(`fix`)에 파란 점 + 헤일로를 찍는다.
  Set<Annotation> _annotations = const {};
  BitmapDescriptor? _meIcon;

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
      // 못 달리는 길(북한 구간)은 그리기만 하고 고르지 못한다.
      if (!r.drivable) continue;
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
    _remap();
  }

  void _remap() {
    _map = AppleMap(
      initialCameraPosition: CameraPosition(
        target: _center,
        zoom: _hasFix ? _zoomNear : _zoomWhole,
      ),
      onMapCreated: (c) => _controller = c,
      onCameraMove: (pos) => _zoom = pos.zoom,
      // 나침반·내 위치 버튼은 우리 UI와 겹친다. 지도는 조용해야 한다.
      compassEnabled: false,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      pitchGesturesEnabled: false,
      rotateGesturesEnabled: false,
      polylines: _polylines,
      annotations: _annotations,
      onTap: _onMapTap,
    );
  }

  void _onMapTap(LatLng at) {
    final onTap = widget.onRouteTap;
    if (onTap == null) return;
    final r = _routeAt(at);
    if (r != null) onTap(r);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 아이콘은 화면 배율을 알아야 그린다 — 여기서 한 번.
    if (_meIcon == null) _prepareMe(MediaQuery.devicePixelRatioOf(context));
  }

  @override
  void didUpdateWidget(RouteMapPanel old) {
    super.didUpdateWidget(old);
    // 위치가 늦게 도착하면 그때 카메라를 옮기고 마커를 찍는다.
    if (!old.fix.sameAs(widget.fix) && _hasFix) {
      _moveTo(_center, _zoomNear);
      _markMe();
    }
    if (!identical(old.routes, widget.routes) || old.selectedId != widget.selectedId) {
      _polylines = _buildPolylines();
      _remap();
    }
    final f = widget.focus;
    if (f != null && f.seq != (old.focus?.seq ?? -1)) _fitRoute(f);
  }

  /// 고른 노선이 화면에 다 들어오게 옮긴다.
  ///
  /// ⚠ 아래는 시트가 덮는다. 플러그인의 bounds 맞춤은 사방 여백이 같아서, 길이 시트 뒤로
  ///   들어간다 — 그래서 **남쪽을 늘린 상자**를 맞춘다. 보이는 비율이 f 면 상자 세로는 길의 1/f.
  Future<void> _fitRoute(MapFocus f) async {
    final route = widget.routes.where((r) => r.id == f.routeId).firstOrNull;
    if (route == null) return;
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    var n = 0;
    for (final chain in route.paths) {
      for (final p in chain) {
        if (p.lat < minLat) minLat = p.lat;
        if (p.lat > maxLat) maxLat = p.lat;
        if (p.lng < minLng) minLng = p.lng;
        if (p.lng > maxLng) maxLng = p.lng;
        n++;
      }
    }
    if (n < 2) return;
    final frac = f.visibleFraction.clamp(0.3, 1.0);
    final latSpan = math.max(maxLat - minLat, 0.05);
    final lngPad = math.max(maxLng - minLng, 0.05) * 0.06;
    final south = minLat - latSpan * (1 - frac) / frac;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, minLng - lngPad),
          northeast: LatLng(maxLat + latSpan * 0.06, maxLng + lngPad),
        ),
        24,
      ),
    );
  }

  /// 갈래마다 따로 그린다. 국도는 끊겨 있어서 한 줄로 이으면 없는 길이 생긴다.
  ///
  /// ⚠ **zIndex 를 쓰지 않는다.** apple_maps_flutter 의 zIndex 는 겹침 순서가 아니라
  ///   `insertOverlay(at:)` 의 **배열 위치**다 — 값을 주면 새 선이 아래로 끼어들어 순서가 뒤섞인다.
  ///   흰 밑선을 깔았더니 실기기에서 선이 죄다 하얗고 87번만 파랬다 (2026-09-09).
  /// ⚠ 전부 같은 파랑이다. 근처/먼 길을 옅기로 나눴다가 뺐다 (2026-09-09) — 지도책의 길은 다 같은 길이다.
  ///   고른 노선만 **노란색**, 맨 나중에 넣어 위에 오게 한다.
  Set<Polyline> _buildPolylines() {
    final out = <Polyline>{};
    final picked = <Polyline>[];
    for (final r in widget.routes) {
      final selected = r.id == widget.selectedId;
      for (var i = 0; i < r.paths.length; i++) {
        final chain = r.paths[i];
        if (chain.length < 2) continue;
        final line = Polyline(
          polylineId: PolylineId('r-${r.id}-$i'),
          points: [for (final p in chain) LatLng(p.lat, p.lng)],
          color: selected ? AppColors.sun : AppColors.routeBlue,
          // 전국이 한 화면일 때 두꺼우면 덩어리가 된다.
          width: selected ? 6 : 4,
        );
        if (selected) {
          picked.add(line);
        } else {
          out.add(line);
        }
      }
    }
    return {...out, ...picked};
  }

  /// 현재 위치 점 — 파란 원 + 흰 테두리 + 옅은 헤일로. 위젯 대신 캔버스로 그려 바이트로 넘긴다.
  /// 플러그인이 화면 배율로 읽으니(`UIImage(data:scale:)`) 논리 34pt × 배율로 그린다.
  Future<void> _prepareMe(double dpr) async {
    const size = 34.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final c = Offset(size / 2 * dpr, size / 2 * dpr);
    canvas.drawCircle(
      c,
      size / 2 * dpr,
      Paint()..color = AppColors.routeBlue.withValues(alpha: 0.16),
    );
    canvas.drawCircle(c, 8 * dpr, Paint()..color = Colors.white);
    canvas.drawCircle(c, 5.5 * dpr, Paint()..color = AppColors.routeBlue);
    final img = await rec.endRecording().toImage((size * dpr).round(), (size * dpr).round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted || bytes == null) return;
    _meIcon = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
    _markMe();
  }

  void _markMe() {
    final icon = _meIcon;
    if (icon == null || !_hasFix) return;
    setState(() {
      _annotations = {
        Annotation(
          annotationId: AnnotationId('me'),
          position: _center,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
        ),
      };
      _remap();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return _MapPending(sheetExtent: widget.sheetExtent);

    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          children: [
            // ⚠ 같은 인스턴스. 여기서 AppleMap(...) 을 새로 쓰면 매 rebuild 마다 51선을 다시 보낸다.
            Positioned.fill(child: _map!),
            // 버튼만 시트를 따라간다 — 지도 서브트리는 이 빌더 바깥이라 손대지 않는다.
            ValueListenableBuilder<double>(
              valueListenable: widget.sheetExtent,
              builder: (context, extent, _) {
                final inset = extent * box.maxHeight;
                // 시트를 끝까지 올리면 지도가 손가락 두 마디만 남는다. 그 위에 버튼 셋을 얹으면 상태바를 뚫는다.
                if (box.maxHeight - inset < 200) return const SizedBox.shrink();
                return Positioned(
                  right: AppSpace.x3,
                  bottom: inset + AppSpace.x3,
                  child: _Controls(
                    onZoomIn: () => _controller?.animateCamera(CameraUpdate.zoomIn()),
                    onZoomOut: () => _controller?.animateCamera(CameraUpdate.zoomOut()),
                    onLocate: _hasFix ? () => _moveTo(_center, _zoomNear) : null,
                  ),
                );
              },
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
  const _MapPending({required this.sheetExtent});
  final ValueListenable<double> sheetExtent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => ValueListenableBuilder<double>(
        valueListenable: sheetExtent,
        builder: (context, extent, _) => _body(extent * box.maxHeight, box.maxHeight),
      ),
    );
  }

  Widget _body(double bottomInset, double height) {
    // 시트가 올라와 지도 자리가 거의 안 남으면 문구를 접는다.
    final free = height - bottomInset;
    return Container(
      color: AppColors.fill,
      padding: EdgeInsets.only(bottom: bottomInset),
      alignment: Alignment.center,
      child: free < 76
          ? const SizedBox.shrink()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 30, color: AppColors.ink3.withValues(alpha: 0.7)),
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
  }
}

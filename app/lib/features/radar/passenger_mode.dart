import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/saves.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';

/// DR-05 동승자 모드.
///
/// 운전자가 못 보는 앞쪽을 동승자가 대신 훑는다. **단말 1대 전제 — 실시간 동기화 없음.**
///
/// ⚠ DR-01과 조건이 다르다: 반경 20km, **신뢰도 게이트 미적용**.
///   얕은 데이터는 알림엔 안 태우되 브라우징엔 보여준다 (§4-5).
/// ⚠ 좌 스와이프(넘기기)는 **스쳐간 발견으로 적립하지 않는다.**
///   동승자가 훑어본 것과 운전자가 지나친 것은 다른 사건이다 (SCREENS.md CO-01 A와 같은 규칙).
/// ⚠ 운전자에게 소리·푸시로 알리지 않는다. 동승자가 정한 걸 운전자가 볼 뿐이다.
class PassengerMode extends ConsumerStatefulWidget {
  const PassengerMode({
    super.key,
    required this.lat,
    required this.lng,
    required this.headingDeg,
    required this.onExit,
    required this.onPick,
    this.picked = const [],
  });

  final double lat;
  final double lng;
  final double headingDeg;
  final VoidCallback onExit;

  /// 동승자가 고른 '다음 정차지 후보'.
  final void Function(Spot) onPick;
  final List<Spot> picked;

  @override
  ConsumerState<PassengerMode> createState() => _PassengerModeState();
}

class _PassengerModeState extends ConsumerState<PassengerMode> {
  int _index = 0;

  /// 앞이 조용하면 더 멀리 본다 (SCREENS.md DR-05 상태).
  double _km = 20;

  /// 조회에 쓰는 좌표. **주행 좌표를 그대로 키로 쓰면 안 된다** —
  /// 250ms마다 바뀌어 family가 매번 새 provider를 만들고 영원히 로딩에 머문다.
  /// 20km를 보는 화면이라 2km쯤 움직였을 때만 다시 묻는다.
  late double _qLat = widget.lat;
  late double _qLng = widget.lng;
  late double _qHeading = _quantize(widget.headingDeg);

  @override
  void didUpdateWidget(PassengerMode old) {
    super.didUpdateWidget(old);
    final movedKm = _roughKm(_qLat, _qLng, widget.lat, widget.lng);
    final turned = (_quantize(widget.headingDeg) - _qHeading).abs() >= 30;
    if (movedKm < 2 && !turned) return;
    setState(() {
      _qLat = widget.lat;
      _qLng = widget.lng;
      _qHeading = _quantize(widget.headingDeg);
      _index = 0;
    });
  }

  /// 방위를 15도 단위로 뭉갠다. 1도 흔들릴 때마다 다시 물을 이유가 없다.
  static double _quantize(double deg) => (deg / 15).roundToDouble() * 15;

  /// 대략 거리(km). 위도 37도 평면 근사면 충분하다.
  static double _roughKm(double aLat, double aLng, double bLat, double bLng) {
    final dx = (bLng - aLng) * 88.0;
    final dy = (bLat - aLat) * 111.0;
    return (dx * dx + dy * dy) <= 0 ? 0 : math.sqrt(dx * dx + dy * dy);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(aheadProvider((lat: _qLat, lng: _qLng, heading: _qHeading, km: _km)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, _) => const Center(
              child: Text(S.errNetwork, style: TextStyle(color: AppColors.darkInk2)),
            ),
            data: (spots) {
              final rest = spots.skip(_index).toList();
              if (rest.isEmpty) return _quiet();
              return _deck(rest.first, rest.length);
            },
          ),
        ),
        if (widget.picked.isNotEmpty) _pickedRow(),
      ],
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 6, AppSpace.x3, AppSpace.x4),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                S.passengerTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkInk,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                S.passengerIntro,
                style: TextStyle(fontSize: 12.5, color: AppColors.darkInk2),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: widget.onExit,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, AppTouch.min),
            foregroundColor: AppColors.darkInk2,
          ),
          child: const Text(S.passengerBack, style: TextStyle(fontSize: 13.5)),
        ),
      ],
    ),
  );

  Widget _quiet() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(S.passengerQuiet, style: TextStyle(fontSize: 14.5, color: AppColors.darkInk2)),
        const SizedBox(height: AppSpace.x3),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, AppTouch.min),
            side: const BorderSide(color: AppColors.darkLine),
            foregroundColor: AppColors.darkInk,
          ),
          // 반경만 넓힌다. 없는 걸 만들어내지 않는다.
          onPressed: _km >= 60 ? null : () => setState(() => _km += 20),
          child: Text('${S.passengerWider} (${_km.round() + 20}km)'),
        ),
      ],
    ),
  );

  Widget _deck(Spot spot, int left) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.x4),
      child: Dismissible(
        key: ValueKey(spot.id),
        // 좌 = 넘기기(적립 없음), 우 = 찜 + 다음 정차지 후보
        onDismissed: (dir) {
          if (dir == DismissDirection.startToEnd) {
            ref.read(savesProvider.notifier).toggleLike(SaveRef.spot(spot.id));
            widget.onPick(spot);
            showAppToast(context, S.passengerPicked);
          }
          setState(() => _index++);
        },
        background: _swipeHint(S.passengerPick, Alignment.centerLeft, AppColors.fieldGreen),
        secondaryBackground: _swipeHint(S.passengerSkip, Alignment.centerRight, AppColors.darkLine),
        child: GestureDetector(
          onTap: () => context.push('/spot/${spot.id}'),
          child: _card(spot, left),
        ),
      ),
    );
  }

  Widget _swipeHint(String label, Alignment align, Color color) => Container(
    alignment: align,
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.x6),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.hero)),
    child: Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
    ),
  );

  Widget _card(Spot spot, int left) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.hero),
    child: Stack(
      fit: StackFit.expand,
      children: [
        SpotImage(type: spot.type, spotId: spot.id, imageUrl: spot.imageUrl, radius: 0),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xD9000000)],
            ),
          ),
        ),
        Positioned(
          left: AppSpace.x5,
          right: AppSpace.x5,
          bottom: AppSpace.x5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 시의성이 있을 때만 칩을 낸다 — 없는 배지를 만들지 않는다.
              if (spot.timeliness != Timeliness.none) ...[
                TimelinessChip(spot.timeliness),
                const SizedBox(height: AppSpace.x2),
              ],
              Text(
                spot.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                spot.blurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xCCFFFFFF)),
              ),
              const SizedBox(height: AppSpace.x3),
              Text(
                // ⚠ 신뢰도 점수를 노출하지 않는다 (원칙 3). 거리만 말한다.
                '국도에서 ${spot.detourMin}분 · 앞으로 $left곳',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0x99FFFFFF),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _pickedRow() => SizedBox(
    height: 62,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.x4),
      itemCount: widget.picked.length,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x2),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: AppColors.darkLine),
        ),
        child: Text(
          widget.picked[i].name,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.darkInk,
          ),
        ),
      ),
    ),
  );
}

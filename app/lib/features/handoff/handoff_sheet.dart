import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_navi/kakao_flutter_sdk_navi.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/base_camp.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

/// HND 내비 핸드오프 시트 (SCREENS.md §HND).
///
/// ⚠ 우리가 내비가 되지 않는다 (CLAUDE.md 원칙 1). 길안내는 외부 앱에 넘긴다.
/// 카카오내비가 주. 티맵은 **목적지 단건만** 보조 지원(경유지 미지원).
enum HandoffMode {
  /// 출발 시 — 목적지=거점, 경유=오늘의 앵커 1~2
  depart,

  /// 이동 중 '들르기' — 스팟 단건
  visit,
}

/// 길안내로 넘길 한 곳. **좌표가 없으면 넘길 수 없다** — 내비는 이름만으로 못 간다.
class HandoffPlace {
  const HandoffPlace(this.name, this.lat, this.lng);
  final String name;
  final double? lat;
  final double? lng;

  bool get hasCoords => lat != null && lng != null;

  Location toLocation() => Location(name: name, x: '$lng', y: '$lat');
}

class HandoffSheet extends StatelessWidget {
  const HandoffSheet({
    super.key,
    required this.mode,
    required this.destination,
    this.via = const [],
    this.showFreeRoadTip = true,
  });

  final HandoffMode mode;
  final HandoffPlace destination;

  String get destinationName => destination.name;

  /// 경유 앵커. **카카오내비만 지원한다** (티맵 공개 딥링크는 목적지 단건까지다).
  /// 카카오내비도 최대 3곳이다.
  final List<HandoffPlace> via;

  List<String> get viaNames => [for (final v in via) v.name];

  /// '무료도로 우선' 안내 — 들르기에선 첫 1회만 (SCREENS.md §HND).
  final bool showFreeRoadTip;

  /// 발견 한 곳에 들를 때 내비로 넘길 값.
  ///
  /// **달리는 중이고 거점이 있으면 거점을 목적지로 두고 발견을 경유지로 넘긴다.**
  /// 그전에는 목적지를 발견으로 바꿔버려서 **오늘 밤 잘 곳이 사라졌다.**
  ///
  /// ⚠ 이건 경로 편집이 아니다. 돌고 있는 카카오내비 세션에 경유지를 꽂는 API는 없다 —
  ///   내비가 새로 열려 현재 위치에서 다시 계산한다. 다만 거점을 잃지 않는다.
  /// ⚠ 달리는 중이 아니면(둘러보다 누른 경우) 지킬 목적지가 없다. 그냥 그 곳으로 간다.
  /// ⚠ 티맵은 경유지를 못 받는다 — 버튼 문구가 '목적지만'인 이유다.
  static ({HandoffPlace destination, List<HandoffPlace> via}) visitParams({
    required HandoffPlace spot,
    required BaseCamp? base,
    required bool driving,
  }) {
    if (!driving || base == null) return (destination: spot, via: const []);
    final camp = HandoffPlace(base.name, base.lat, base.lng);
    if (!camp.hasCoords) return (destination: spot, via: const []);
    return (destination: camp, via: [spot]);
  }

  static Future<void> show(
    BuildContext context, {
    required HandoffMode mode,
    required HandoffPlace destination,
    List<HandoffPlace> via = const [],
    bool showFreeRoadTip = true,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HandoffSheet(
        mode: mode,
        destination: destination,
        via: via,
        showFreeRoadTip: showFreeRoadTip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 12, AppSpace.gutter, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.x5),
          // 들르기인데 경유가 있으면 **사용자가 누른 그 곳**이 제목이다. 목적지(거점)가 아니라.
          Text(
            mode == HandoffMode.depart
                ? S.handoffTitle
                : (viaNames.isEmpty ? destinationName : viaNames.first),
            style: AppType.h2,
          ),
          const SizedBox(height: AppSpace.x4),
          // ⚠ 거점을 지킨 채 들른다는 걸 눈으로 보여준다. 안 보여주면
          //   목적지가 바뀐 줄 알고 불안해진다.
          if (mode == HandoffMode.depart || viaNames.isNotEmpty) ...[
            _row('목적지', destinationName),
            if (viaNames.isNotEmpty) ...[
              const SizedBox(height: AppSpace.x2),
              _row('경유', viaNames.join(' · ')),
            ],
            const SizedBox(height: AppSpace.x4),
          ],
          if (showFreeRoadTip)
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FC),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Text(
                S.handoffFreeRoad,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: Color(0xFF1A3E9E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: AppSpace.x5),
          SizedBox(
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.routeBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              onPressed: () => _openKakao(context),
              child: const Text(
                S.handoffKakao,
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.x2),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.line2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              onPressed: () => _openTmap(context),
              child: const Text(
                S.handoffTmap,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.x2),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소', style: TextStyle(color: AppColors.ink2)),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  /// 카카오내비 — 실호출. 경유지는 최대 3곳까지 넘긴다 (TECH_SPEC §3.3).
  ///
  /// ⚠ 무료도로 우선([RpOption.free])으로 넘긴다. 시트에 그렇게 써 놓고
  ///   고속도로로 안내하면 말이 다르다 — 이 앱이 국도 앱인 이유이기도 하다.
  Future<void> _openKakao(BuildContext context) async {
    if (!destination.hasCoords) return _noCoords(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      if (await NaviApi.instance.isKakaoNaviInstalled()) {
        await NaviApi.instance.navigate(
          destination: destination.toLocation(),
          option: NaviOption(coordType: CoordType.wgs84, rpOption: RpOption.free),
          viaList: [for (final v in via.where((v) => v.hasCoords).take(3)) v.toLocation()],
        );
        nav.pop();
        return;
      }
    } catch (e) {
      // SDK가 실패하면 삼키지 않고 말한다. 조용히 아무 일도 안 일어나는 게 제일 나쁘다.
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('카카오내비를 열지 못했어요 · $e'), duration: AppMotion.toast),
      );
      return;
    }
    nav.pop();
    await _openStore(kakao: true);
  }

  /// 티맵은 공개 딥링크가 목적지 단건 수준이라 보조 지원 (TECH_SPEC §3.3).
  Future<void> _openTmap(BuildContext context) async {
    if (!destination.hasCoords) return _noCoords(context);
    final nav = Navigator.of(context);
    final uri = Uri.parse(
      'tmap://route?goalname=${Uri.encodeComponent(destination.name)}'
      '&goalx=${destination.lng}&goaly=${destination.lat}',
    );
    final ok = await _launch(uri);
    nav.pop();
    if (!ok) await _openStore(kakao: false);
  }

  void _noCoords(BuildContext context) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(S.handoffNoCoords), duration: AppMotion.toast));
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// 미설치 → 스토어로 (SCREENS.md §HND 예외).
  /// ⚠ `market://`는 안드로이드 전용이다. iOS에서는 아무것도 안 열린다.
  Future<void> _openStore({required bool kakao}) async {
    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/kr/app/id${kakao ? '417698849' : '431589174'}')
        : Uri.parse('market://details?id=${kakao ? 'com.locnall.KimGiSa' : 'com.skt.tmap.ku'}');
    await _launch(uri);
  }
}

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_navi/kakao_flutter_sdk_navi.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/settings.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

/// HND 내비 핸드오프 시트 (SCREENS.md §HND).
///
/// ⚠ 우리가 내비가 되지 않는다 (CLAUDE.md 원칙 1). 길안내는 외부 앱에 넘긴다.
/// 카카오내비가 주, 애플 지도가 보조. **티맵은 뺐다** (2026-09-08).
///
/// ⚠ **어느 앱을 골랐는지 돌려준다.** 레이더는 이 값이 와야 돈다 (DR-01 진입, 2026-09-08).
///   내리면(스와이프·바깥 탭) null — '안내 없이' 버튼은 따로 두지 않는다. 내리는 게 곧 그것이다.
enum HandoffMode {
  /// 출발 시 — 목적지=그 길의 진입점
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

class HandoffSheet extends StatefulWidget {
  const HandoffSheet({
    super.key,
    required this.mode,
    required this.destination,
    this.via = const [],
    this.showFreeRoadTip = true,
    this.remembered,
  });

  final HandoffMode mode;
  final HandoffPlace destination;

  String get destinationName => destination.name;

  /// 경유 앵커. **카카오내비만 지원한다** (애플 지도 공개 URL 은 목적지 단건까지다).
  /// 카카오내비도 최대 3곳이다.
  final List<HandoffPlace> via;

  List<String> get viaNames => [for (final v in via) v.name];

  /// 경유를 못 넘기는 앱(애플 지도)이 갈 곳.
  ///
  /// ⚠ 거점을 없애면서(2026-09-07) '들르기'의 목적지는 **언제나 누른 그곳**이 됐다.
  ///   경유지는 남겨 둔다 — 코스 앵커 같은 다른 쓰임이 생길 수 있고, 있으면 그게 먼저다.
  HandoffPlace get singleTarget => via.isNotEmpty ? via.first : destination;

  /// '무료도로 우선' 안내 — 들르기에선 첫 1회만 (SCREENS.md §HND).
  final bool showFreeRoadTip;

  /// 지난번에 고른 앱. 있으면 그 버튼 하나만 크게 — 「다른 앱으로」 로 둘 다 볼 수 있다.
  final NavApp? remembered;

  /// 시트를 띄우고 **고른 앱**을 돌려준다. 내리면 null.
  static Future<NavApp?> show(
    BuildContext context, {
    required HandoffMode mode,
    required HandoffPlace destination,
    List<HandoffPlace> via = const [],
    bool showFreeRoadTip = true,
  }) {
    final remembered = ProviderScope.containerOf(context, listen: false).read(navAppProvider);
    return showModalBottomSheet<NavApp>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HandoffSheet(
        mode: mode,
        destination: destination,
        via: via,
        showFreeRoadTip: showFreeRoadTip,
        remembered: remembered,
      ),
    );
  }

  @override
  State<HandoffSheet> createState() => _HandoffSheetState();
}

class _HandoffSheetState extends State<HandoffSheet> {
  /// 기억한 앱이 있어도 「다른 앱으로」 를 누르면 둘 다 보인다.
  bool _showAll = false;

  HandoffMode get mode => widget.mode;
  HandoffPlace get destination => widget.destination;
  List<HandoffPlace> get via => widget.via;
  List<String> get viaNames => widget.viaNames;
  HandoffPlace get singleTarget => widget.singleTarget;

  @override
  Widget build(BuildContext context) {
    final remembered = _showAll ? null : widget.remembered;
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
          // 들르기인데 경유가 있으면 **사용자가 누른 그 곳**이 제목이다.
          Text(
            mode == HandoffMode.depart
                ? S.handoffTitle
                : (viaNames.isEmpty ? widget.destinationName : viaNames.first),
            style: AppType.h2,
          ),
          const SizedBox(height: AppSpace.x4),
          if (mode == HandoffMode.depart || viaNames.isNotEmpty) ...[
            _row('목적지', widget.destinationName),
            if (viaNames.isNotEmpty) ...[
              const SizedBox(height: AppSpace.x2),
              _row('경유', viaNames.join(' · ')),
            ],
            const SizedBox(height: AppSpace.x4),
          ],
          if (widget.showFreeRoadTip)
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
          // ⚠ 애플 지도를 빼지 말 것 — 없으면 심사에서 반려된다 (Guideline 4).
          //   기억한 앱이 있으면 그것만 크게. 없으면 카카오가 주, 애플이 보조.
          if (remembered == NavApp.apple) ...[
            _primary(S.handoffApple, () => _openApple(context)),
            _otherApp(),
          ] else if (remembered == NavApp.kakao) ...[
            _primary(S.handoffKakao, () => _openKakao(context)),
            _otherApp(),
          ] else ...[
            _primary(S.handoffKakao, () => _openKakao(context)),
            const SizedBox(height: AppSpace.x2),
            _secondary(S.handoffApple, () => _openApple(context)),
          ],
          // 경유가 있을 때만 말한다. 없으면 굳이 할 말이 아니다.
          if (via.isNotEmpty) ...[
            const SizedBox(height: AppSpace.x2),
            Text(
              S.handoffDestOnly(singleTarget.name),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.ink3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _primary(String label, VoidCallback onTap) => SizedBox(
    height: 56,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.routeBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
    ),
  );

  Widget _secondary(String label, VoidCallback onTap) => SizedBox(
    height: 52,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    ),
  );

  Widget _otherApp() => TextButton(
    onPressed: () => setState(() => _showAll = true),
    child: const Text(S.handoffOtherApp, style: TextStyle(color: AppColors.ink2)),
  );

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

  /// 고른 앱을 기억한다. ⚠ 골든 테스트는 ProviderScope 없이 이 위젯을 그리는데,
  ///   거기선 아무도 버튼을 누르지 않는다 — 그래도 못 찾으면 조용히 건너뛴다.
  void _remember(BuildContext context, NavApp app) {
    try {
      ProviderScope.containerOf(context, listen: false).read(navAppProvider.notifier).set(app);
    } catch (_) {
      /* 기억 못 해도 안내는 나간다 */
    }
  }

  /// 카카오내비 — 실호출. 경유지는 최대 3곳까지 넘긴다 (TECH_SPEC §3.3).
  ///
  /// ⚠ 무료도로 우선([RpOption.free])으로 넘긴다. 시트에 그렇게 써 놓고
  ///   고속도로로 안내하면 말이 다르다 — 이 앱이 국도 앱인 이유이기도 하다.
  /// ⚠ 미설치면 스토어로 보내고도 **고른 것으로 친다** — 설치하고 돌아와 달릴 수 있게
  ///   레이더는 켜 둔다.
  Future<void> _openKakao(BuildContext context) async {
    if (!destination.hasCoords) return _noCoords(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    _remember(context, NavApp.kakao);
    try {
      if (await NaviApi.instance.isKakaoNaviInstalled()) {
        await NaviApi.instance.navigate(
          destination: destination.toLocation(),
          option: NaviOption(coordType: CoordType.wgs84, rpOption: RpOption.free),
          viaList: [for (final v in via.where((v) => v.hasCoords).take(3)) v.toLocation()],
        );
        nav.pop(NavApp.kakao);
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
    nav.pop(NavApp.kakao);
    await _openStore();
  }

  /// 애플 지도 — iOS 기본 지도.
  ///
  /// ⚠ **선택지로 반드시 있어야 한다.** 2026-09-02 App Store 반려 사유가
  ///   "내장 지도와 연결되지 않아 서드파티 지도 앱에 묶는다"였다 (Guideline 4).
  /// ⚠ 이름을 안 넘기고 **좌표로만** 보낸다. 이름으로 검색시키면 엉뚱한 곳이 잡힌다 —
  ///   '중앙시장'처럼 전국에 널린 이름이 많다.
  /// ⚠ 경유지를 못 넘긴다. 공개 URL 스킴에 그런 파라미터가 없다.
  Future<void> _openApple(BuildContext context) async {
    final target = singleTarget;
    if (!target.hasCoords) return _noCoords(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _remember(context, NavApp.apple);
    final ok = await _launch(
      Uri.parse('https://maps.apple.com/?daddr=${target.lat},${target.lng}&dirflg=d'),
    );
    if (!ok) {
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text(S.handoffNoMap), duration: AppMotion.toast),
      );
      return;
    }
    nav.pop(NavApp.apple);
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

  /// 카카오내비 미설치 → 스토어로 (SCREENS.md §HND 예외).
  /// ⚠ `market://`는 안드로이드 전용이다. iOS에서는 아무것도 안 열린다.
  Future<void> _openStore() async {
    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/kr/app/id417698849')
        : Uri.parse('market://details?id=com.locnall.KimGiSa');
    await _launch(uri);
  }
}

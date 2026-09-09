import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';

/// HND 내비 핸드오프 시트 (SCREENS.md §HND).
///
/// ⚠ 우리가 내비가 되지 않는다 (CLAUDE.md 원칙 1). 길안내는 외부 앱에 넘긴다.
/// 티맵과 애플 지도 **둘 다 언제나 보인다.**
///
/// ⚠ **카카오내비 → 티맵 (2026-09-09).** 카카오내비는 안내 중엔 새 목적지를 거절한다 —
///   「들르기」를 누르면 "주행 중에는 사용할 수 없는 기능" 얼럿만 떴다 (카카오모빌리티 공식:
///   "주행 중에는 새 목적지를 검색할 수 없습니다", devtalk 149550). 티맵은 안내 중에 URL 스킴으로
///   새 목적지를 보내면 **경로를 바꾼다** — 실기기로 확인했다. 카카오내비 코드는 지웠다
///   (SDK 의존·`KakaoSdk.init`·URL 스킴 선언까지). 지도(kakao_map_sdk)와는 별개다.
///
/// ⚠ **애플 지도를 접어 두지 않는다** (2026-09-09). 한 번 고른 앱을 기억해 그 버튼 하나만
///   보이고 「다른 앱으로」 뒤에 애플 지도를 숨겼는데, 그게 지난 반려(Guideline 4 —
///   "내장 지도와 연결되지 않는다")를 그대로 다시 부르는 모양이다. 뎁스 없이 둘 다.
///
/// ⚠ **어느 앱을 골랐는지 돌려준다.** 레이더는 이 값이 와야 돈다 (DR-01 진입, 2026-09-08).
///   내리면(스와이프·바깥 탭) null — '안내 없이' 버튼은 따로 두지 않는다. 내리는 게 곧 그것이다.
enum HandoffMode {
  /// 출발 시 — 목적지=그 길의 진입점
  depart,

  /// 이동 중 '들르기' — 스팟 단건
  visit,
}

/// 시트가 돌려주는 값 — 어느 앱으로 넘어갔는가.
enum NavApp { tmap, apple }

/// 길안내로 넘길 한 곳. **좌표가 없으면 넘길 수 없다** — 내비는 이름만으로 못 간다.
class HandoffPlace {
  const HandoffPlace(this.name, this.lat, this.lng);
  final String name;
  final double? lat;
  final double? lng;

  bool get hasCoords => lat != null && lng != null;
}

class HandoffSheet extends StatelessWidget {
  const HandoffSheet({
    super.key,
    required this.mode,
    required this.destination,
    this.via = const [],
    this.showFreeRoadTip = true,
    this.routeId,
  });

  final HandoffMode mode;
  final HandoffPlace destination;

  /// 출발 시 그 길의 번호. 제목이 **길 이름으로** 말한다 — 앱 이름이 아니다.
  final int? routeId;

  String get destinationName => destination.name;

  /// 경유 앵커. ⚠ **티맵·애플 지도 둘 다 못 넘긴다** — 공개 URL 스킴이 목적지 단건까지다.
  final List<HandoffPlace> via;

  List<String> get viaNames => [for (final v in via) v.name];

  /// 경유를 못 넘기는 앱(티맵 · 애플 지도)이 갈 곳.
  ///
  /// ⚠ 거점을 없애면서(2026-09-07) '들르기'의 목적지는 **언제나 누른 그곳**이 됐다.
  ///   경유지는 남겨 둔다 — 코스 앵커 같은 다른 쓰임이 생길 수 있고, 있으면 그게 먼저다.
  HandoffPlace get singleTarget => via.isNotEmpty ? via.first : destination;

  /// '무료도로 우선' 안내 — 들르기에선 첫 1회만 (SCREENS.md §HND).
  final bool showFreeRoadTip;

  /// 시트를 띄우고 **고른 앱**을 돌려준다. 내리면 null.
  static Future<NavApp?> show(
    BuildContext context, {
    required HandoffMode mode,
    required HandoffPlace destination,
    List<HandoffPlace> via = const [],
    bool showFreeRoadTip = true,
    int? routeId,
  }) {
    return showModalBottomSheet<NavApp>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HandoffSheet(
        mode: mode,
        destination: destination,
        via: via,
        showFreeRoadTip: showFreeRoadTip,
        routeId: routeId,
      ),
    );
  }

  String get _title {
    if (mode == HandoffMode.visit) return viaNames.isEmpty ? destinationName : viaNames.first;
    final id = routeId;
    return id == null ? S.handoffTitle : S.handoffTitleRoute(id);
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
          // 들르기인데 경유가 있으면 **사용자가 누른 그 곳**이 제목이다.
          Text(_title, style: AppType.h2),
          const SizedBox(height: AppSpace.x4),
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
          // ⚠ 둘 다 **언제나** 보인다. 애플 지도를 빼거나 접으면 심사에서 반려된다 (Guideline 4).
          _primary(S.handoffTmap, () => _openTmap(context)),
          const SizedBox(height: AppSpace.x2),
          _secondary(S.handoffApple, () => _openApple(context)),
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

  /// 티맵 — 공개 URL 스킴 `tmap://route?rGoName=&rGoX=&rGoY=` (SK 개발자 문서의 앱 연동 형식).
  ///
  /// ⚠ **안내 중에도 받는다.** 티맵이 이미 안내 중일 때 이 URL 을 열면 경로가 새 목적지로
  ///   바뀐다 — 실기기 확인 (2026-09-09). 카카오내비는 이걸 거절했다.
  /// ⚠ 경로 옵션은 못 넘긴다. 카카오내비 SDK 는 '무료도로 우선'을 코드로 줬는데, 티맵 URL 엔
  ///   그 파라미터가 없다 → 시트의 안내문이 사용자에게 고르라고 말한다 (`S.handoffFreeRoad`).
  /// ⚠ 이름은 참고용이고 **좌표가 목적지**다. 좌표 없으면 못 넘긴다.
  /// ⚠ 미설치면 스토어로 보내고도 **고른 것으로 친다** — 설치하고 돌아와 달릴 수 있게
  ///   레이더는 켜 둔다.
  Future<void> _openTmap(BuildContext context) async {
    final target = singleTarget;
    if (!target.hasCoords) return _noCoords(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // 공백은 %20 으로. `queryParameters` 는 '+' 로 바꾸는데, 앱마다 그걸 공백으로 안 읽기도 한다.
    final uri = Uri.parse(
      'tmap://route?rGoName=${Uri.encodeComponent(target.name)}&rGoX=${target.lng}&rGoY=${target.lat}',
    );
    var installed = false;
    try {
      // LSApplicationQueriesSchemes 에 `tmap` 이 있어야 true 가 온다 (Info.plist).
      installed = await canLaunchUrl(uri);
    } catch (_) {
      installed = false;
    }
    if (installed) {
      final ok = await _launch(uri);
      if (!ok) {
        nav.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text(S.handoffNoMap), duration: AppMotion.toast),
        );
        return;
      }
      nav.pop(NavApp.tmap);
      return;
    }
    nav.pop(NavApp.tmap);
    await _openTmapStore();
  }

  /// 티맵 미설치 → 스토어로 (SCREENS.md §HND 예외).
  Future<void> _openTmapStore() async {
    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/kr/app/id431589174')
        : Uri.parse('market://details?id=com.skt.tmap.ku');
    await _launch(uri);
  }

  /// 애플 지도 — iOS 기본 지도.
  ///
  /// ⚠ **선택지로 반드시, 뎁스 없이 있어야 한다.** 2026-09-02 App Store 반려 사유가
  ///   "내장 지도와 연결되지 않아 서드파티 지도 앱에 묶는다"였다 (Guideline 4).
  /// ⚠ 이름을 안 넘기고 **좌표로만** 보낸다. 이름으로 검색시키면 엉뚱한 곳이 잡힌다 —
  ///   '중앙시장'처럼 전국에 널린 이름이 많다.
  /// ⚠ 경유지를 못 넘긴다. 공개 URL 스킴에 그런 파라미터가 없다.
  Future<void> _openApple(BuildContext context) async {
    final target = singleTarget;
    if (!target.hasCoords) return _noCoords(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
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
}

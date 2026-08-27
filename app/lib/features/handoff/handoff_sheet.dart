import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

class HandoffSheet extends StatelessWidget {
  const HandoffSheet({
    super.key,
    required this.mode,
    required this.destinationName,
    this.viaNames = const [],
    this.showFreeRoadTip = true,
  });

  final HandoffMode mode;
  final String destinationName;

  /// 경유 앵커. 카카오내비만 지원한다.
  final List<String> viaNames;

  /// '무료도로 우선' 안내 — 들르기에선 첫 1회만 (SCREENS.md §HND).
  final bool showFreeRoadTip;

  static Future<void> show(
    BuildContext context, {
    required HandoffMode mode,
    required String destinationName,
    List<String> viaNames = const [],
    bool showFreeRoadTip = true,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HandoffSheet(
        mode: mode,
        destinationName: destinationName,
        viaNames: viaNames,
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
          Text(mode == HandoffMode.depart ? S.handoffTitle : destinationName, style: AppType.h2),
          const SizedBox(height: AppSpace.x4),
          if (mode == HandoffMode.depart) ...[
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

  // TODO(M3): kakao_flutter_sdk_navi의 NaviApi.navigate로 교체.
  //   출발 시 viaList로 앵커 1~2 전달 (TECH_SPEC §3.3). M0.5 실기기 검증 후.
  Future<void> _openKakao(BuildContext context) async {
    final ok = await _launch(Uri.parse('kakaonavi://navigate'));
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!ok) await _openStore('kakaonavi');
  }

  /// 티맵은 공개 딥링크가 목적지 단건 수준이라 보조 지원 (TECH_SPEC §3.3).
  Future<void> _openTmap(BuildContext context) async {
    final ok = await _launch(
      Uri.parse('tmap://route?goalname=${Uri.encodeComponent(destinationName)}'),
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!ok) await _openStore('tmap');
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// 미설치 → 스토어로 (SCREENS.md §HND 예외).
  Future<void> _openStore(String app) async {
    final id = app == 'tmap' ? 'com.skt.tmap.ku' : 'com.locnall.KimGiSa';
    await _launch(Uri.parse('market://details?id=$id'));
  }
}

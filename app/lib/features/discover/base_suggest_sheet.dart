import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// CO-06b 국도 제안 — 역진입 전용 모달 (SCREENS.md §CO-06b, TECH_SPEC §3.7).
///
/// ⚠ 원칙 경계 (CLAUDE.md 원칙 1의 유일한 예외):
///  - 소요시간 비교는 **거점 확정 직후 1회 정적 조회**로만 얻는다
///  - 두 시간은 **비교 근거**일 뿐 ETA가 아니다. 도착 시각 환산·이동 중 갱신 금지
///  - **앵커(장날·행사·일몰)가 0건이면 이 모달을 띄우지 않는다** —
///    설득 근거 없이 40분을 더 쓰라고 하지 않는다
///  - 거절해도 아무 일도 일어나지 않고, 다시 묻지 않는다
class BaseSuggestSheet extends StatelessWidget {
  const BaseSuggestSheet({
    super.key,
    required this.baseName,
    required this.highwayLabel,
    required this.routeLabel,
    required this.routeId,
    required this.anchorText,
    required this.discoveryCount,
  });

  final String baseName;
  final String highwayLabel;
  final String routeLabel;
  final int routeId;
  final String anchorText;
  final int discoveryCount;

  /// 앵커가 없으면 아무것도 띄우지 않고 그대로 반환한다.
  static Future<bool> show(BuildContext context, {required String baseName}) async {
    // TODO(M2): Edge Function compare_routes 호출로 교체 (TECH_SPEC §3.7).
    //   ⚠ 아래 소요시간은 **임시값**이다. 실값은 거점 확정 직후 1회 정적 조회로 받는다.
    //   ⚠ 이 값을 ETA·도착시각으로 환산하지 않는다. 비교 근거일 뿐이다.
    const anchor = '오늘이 북평 장날이고';
    const discoveries = 9;

    // 앵커가 0건이면 모달을 띄우지 않는다 — 설득 근거 없이 40분을 더 쓰라고 하지 않는다
    if (anchor.isEmpty) return false;

    final picked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const BaseSuggestSheet(
        baseName: '',
        highwayLabel: '2시간 10분',
        routeLabel: '2시간 50분',
        routeId: 7,
        anchorText: anchor,
        discoveryCount: discoveries,
      ),
    );
    return picked ?? false;
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
          Text('고속도로로 $highwayLabel.\n근데 $routeLabel으로 가면 $routeId번 국도.', style: AppType.h2),
          const SizedBox(height: AppSpace.x3),
          Text(
            '대신 $anchorText, 가는 길에 발견 $discoveryCount곳이 있어요.',
            style: AppType.body.copyWith(color: AppColors.ink2),
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
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                '국도로 갈래요',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.x2),
          TextButton(
            // 거절해도 아무 일도 일어나지 않는다. 다시 묻지 않는다.
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('고속도로로 갈게요', style: TextStyle(color: AppColors.ink2)),
          ),
        ],
      ),
    );
  }
}

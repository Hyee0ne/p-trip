import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';

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

  /// 실제로 물어보고 띄운다 (TECH_SPEC §3.7).
  ///
  /// ⚠ 아무것도 지어내지 않는다. 셋 중 하나라도 없으면 **모달을 띄우지 않는다**:
  ///   위치 / 소요시간 비교 / 앵커(오늘 장날). 근거 없이 더 오래 걸리는 길을 권하지 않는다.
  /// ⚠ 국도가 더 빠르면 Edge Function이 `not_slower`로 거절한다 —
  ///   '느린 길을 권하는' 이 모달의 전제가 깨지기 때문이다.
  /// ⚠ 앵커는 **오늘 장날만** 본다. SCREENS는 행사·일몰도 허용하지만,
  ///   그 문구 모양이 승인된 적 없어 임의로 만들지 않았다.
  static Future<bool> show(
    BuildContext context,
    WidgetRef ref, {
    required String baseName,
    required double baseLat,
    required double baseLng,
  }) async {
    final fix = await ref.read(currentLocationProvider.future);
    if (!fix.hasFix) return false;

    final repo = ref.read(discoverRepositoryProvider);
    final cmp = await repo.compareRoutes(
      fromLat: fix.lat!,
      fromLng: fix.lng!,
      toLat: baseLat,
      toLng: baseLng,
    );
    if (cmp == null) return false;

    // 앵커 — 오늘 장날이 서는 곳. 없으면 설득할 말이 없다.
    final today = await repo.spots(axis: CurationAxis.today);
    final market = today.where((s) => s.timeliness == Timeliness.marketDay).firstOrNull;
    if (market == null) return false;

    if (!context.mounted) return false;
    final picked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BaseSuggestSheet(
        baseName: baseName,
        highwayLabel: RouteCompare.label(cmp.highwayMin),
        routeLabel: RouteCompare.label(cmp.routeMin),
        routeId: market.routeId,
        anchorText: '오늘이 ${market.name} 장날이고',
        discoveryCount: today.length,
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

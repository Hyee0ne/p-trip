import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/base_camp.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/view_mode.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/route_preview.dart';
import '../../core/widgets/spot_image.dart';
import '../../core/widgets/view_toggle.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../handoff/handoff_sheet.dart';

/// CO-02 코스 상세 (SCREENS.md CO-02).
///
/// 뷰 모드가 여기서도 적용된다 — 9곳을 아홉 번 넘기지 않게 하는 게 목적.
/// ⚠ ETA·도착시간 표기 금지. '순수 주행 2:10'까지만.
/// ⚠ 정렬 칩을 두지 않는다. 순서는 항상 '지나는 순서'.
class CourseScreen extends ConsumerWidget {
  const CourseScreen({super.key, required this.courseId});
  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(courseProvider(courseId));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, _) => const Center(child: Text(S.errNetwork)),
        data: (c) => c == null ? const Center(child: Text(S.errNetwork)) : _Body(course: c),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);
    final spotsAsync = ref.watch(courseSpotsProvider(course.id));

    return Stack(
      children: [
        ListView(
          // 하단 고정 CTA + 탭바 높이만큼 비운다
          padding: const EdgeInsets.only(bottom: 132),
          children: [
            SafeArea(bottom: false, child: _appBar(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: RoutePreview(routeId: course.routeId, height: 150),
            ),
            const SizedBox(height: AppSpace.x4),
            _stats(),
            const SizedBox(height: AppSpace.x3),
            _baseBanner(context),
            const SizedBox(height: AppSpace.x6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: SectionLabel(S.courseDiscoveries, trailing: S.courseOrder),
            ),
            const SizedBox(height: AppSpace.x3),
            spotsAsync.maybeWhen(
              orElse: () => const SizedBox(height: 120),
              data: (spots) =>
                  mode == ViewMode.oneByOne ? _carousel(context, spots) : _list(context, spots),
            ),
          ],
        ),
        _cta(context),
      ],
    );
  }

  Widget _appBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 14, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop(),
          ),
          RouteBadge('${course.routeId}', size: BadgeSize.sm),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              course.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const ViewToggle(),
        ],
      ),
    );
  }

  Widget _stats() {
    Widget cell(String value, String unit, String label) => Expanded(
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              style: AppType.h2.copyWith(fontSize: 19, color: AppColors.ink),
              children: [
                TextSpan(text: value),
                TextSpan(text: unit, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadow.card,
        ),
        child: Row(
          children: [
            cell('${course.distanceKm}', 'km', '총 거리'),
            const _VDivider(),
            // ⚠ 도착 시각이 아니다. 순수 주행시간까지만.
            cell(course.durationLabel, '', '순수 주행시간'),
            const _VDivider(),
            cell('${course.spotIds.length}', '곳', '발견'),
          ],
        ),
      ),
    );
  }

  Widget _baseBanner(BuildContext context) {
    // TODO(M2): 거점 설정 상태를 글로벌 상태로 읽어 '설정됨' 배너로 전환
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: GestureDetector(
        onTap: () => context.push('/course/${course.id}/base'),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.tintViolet,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: const Color(0x6B6D4AA8),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.cabin_outlined, size: 20, color: AppColors.violet),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.baseNone,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onTintViolet,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(S.baseNoneSub, style: TextStyle(fontSize: 11.5, color: Color(0xFF6B5292))),
                  ],
                ),
              ),
              const Text(
                '정하기 ›',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.violet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 「한 곳씩」 — 발견을 가로 캐러셀 전면 카드로.
  Widget _carousel(BuildContext context, List<Spot> spots) {
    return SizedBox(
      height: 244,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        itemCount: spots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 13),
        itemBuilder: (_, i) => SizedBox(
          width: 200,
          child: GestureDetector(
            onTap: () => context.push('/spot/${spots[i].id}'),
            child: _MiniFullBleed(spot: spots[i]),
          ),
        ),
      ),
    );
  }

  /// 「훑어보기」 — 리스트 행으로 한 화면에 모두.
  Widget _list(BuildContext context, List<Spot> spots) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Column(
        children: [
          for (var i = 0; i < spots.length; i++) ...[
            Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${i + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SpotListRow(
                    spot: spots[i],
                    onTap: () => context.push('/spot/${spots[i].id}'),
                  ),
                ),
              ],
            ),
            if (i != spots.length - 1)
              const Divider(height: 1, thickness: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }

  /// 거점 미설정이면 CO-06으로 유도(강제하지 않는다), 설정됐으면 HND 시트.
  void _onDepart(BuildContext context) {
    final base = ProviderScope.containerOf(context).read(baseCampProvider);
    if (base == null) {
      showAppToast(context, S.courseStartWithoutBase);
      context.push('/course/${course.id}/base');
      return;
    }
    // 출발 = 거점이 목적지. 경유는 코스 위 '오늘의 앵커'인데, 아직 앵커 선정 로직이
    // 없어서 비워 둔다 — 없는 경유지를 지어내지 않는다 (TECH_SPEC §3.3).
    HandoffSheet.show(
      context,
      mode: HandoffMode.depart,
      destination: HandoffPlace(base.name, base.lat, base.lng),
    );
  }

  Widget _cta(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 12, AppSpace.gutter, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [AppColors.bg, AppColors.bg, Color(0x00F6FAFB)],
            stops: [0, 0.66, 1],
          ),
        ),
        child: SizedBox(
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.routeBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
            onPressed: () => _onDepart(context),
            child: const Text(
              S.courseStart,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 34, color: AppColors.line);
}

class _MiniFullBleed extends StatelessWidget {
  const _MiniFullBleed({required this.spot});
  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SpotImage(type: spot.type, spotId: spot.id, imageUrl: spot.imageUrl, radius: 18),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xA8140E08), Color(0x00140E08)],
                stops: [0, 0.5],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (spot.timeliness != Timeliness.none)
                  TimelinessChip(spot.timeliness, compact: true),
                const SizedBox(height: 8),
                Text(
                  spot.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '국도에서 ${spot.detourMin}분',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xE0FFFFFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

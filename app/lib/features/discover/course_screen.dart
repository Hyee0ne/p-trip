import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/geo.dart';
import '../../core/journey.dart';
import '../../core/location.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/route_preview.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../handoff/handoff_sheet.dart';

/// 이미 코스 위라고 볼 거리. CO-08 `depart_sheet` 와 같은 값이다.
const _entryThresholdKm = 0.3;

/// 출발할 때 위치를 기다려 주는 시간. 넘으면 안내 없이 그냥 달린다.
const _locWait = Duration(seconds: 3);

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
            const SizedBox(height: AppSpace.x6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: SectionLabel(S.courseDiscoveries, trailing: S.courseOrder),
            ),
            const SizedBox(height: AppSpace.x3),
            spotsAsync.maybeWhen(
              orElse: () => const SizedBox(height: 120),
              data: (spots) =>
                  // 뷰 토글이 없어졌다 (2026-08-30). 코스는 '짜여진 것'을 보는 화면이라
                  // 목록 하나면 된다 — 캐러셀은 같은 걸 느리게 보여줄 뿐이었다.
                  _list(context, spots),
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

  /// 「한 곳씩」 — 발견을 가로 캐러셀 전면 카드로.

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

  /// 코스로 출발할 때의 여정. 선형은 코스 것을 그대로 쓴다.
  static Future<void> _setJourney(ProviderContainer c, Course course) async {
    final path = await c.read(courseGeometryProvider(course.id).future);
    c
        .read(startedJourneyProvider.notifier)
        .set(
          Journey(
            routeId: course.routeId,
            routeName: course.title,
            path: path,
            courseId: course.id,
            startName: course.startName,
            endName: course.endName,
          ),
        );
  }

  /// 코스 진입점까지 데려다주고 레이더로 넘긴다.
  ///
  /// ⚠ 거점을 없앴다 (2026-09-07). 전에는 거점이 목적지였고, 없으면 CO-06으로 유도했다.
  ///   이제 노선 출발(CO-08 `depart_sheet`)과 **같은 문법**이다 — 목적지는 그 길의 진입점이다.
  /// ⚠ 코스 끝을 목적지로 잡으면 카카오내비가 최단 경로로 안내해 **고속도로로 빠진다.**
  ///   국도를 타려고 켠 내비가 국도를 벗어나게 만드는 셈이다. 짧게 끊어야 그 일이 안 생긴다.
  /// ⚠ 위치를 모르거나 이미 코스 위면 안내할 게 없다. 막지 않고 그냥 달린다.
  Future<void> _onDepart(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    // 레이더가 **이 코스**를 달린다. 안 넘기면 무슨 코스를 골랐든 데모 코스가 돈다.
    await _setJourney(container, course);
    if (!context.mounted) return;

    final path = await container.read(courseGeometryProvider(course.id).future);
    // ⚠ **위치를 기다리느라 출발을 붙잡지 않는다.** GPS 를 못 잡으면 getCurrentPosition 이
    //   8초까지 버티는데, 그동안 버튼을 누른 사람은 아무 반응 없는 화면을 본다.
    //   못 받으면 안내를 못 붙일 뿐이다 — 달리는 건 막지 않는다.
    final fix = await container
        .read(currentLocationProvider.future)
        .timeout(_locWait, onTimeout: () => const LocFix(LocStatus.unavailable));
    if (!context.mounted) return;

    if (path.isNotEmpty && fix.hasFix) {
      final entry = path.first;
      if (roughKm(fix.lat!, fix.lng!, entry.lat, entry.lng) > _entryThresholdKm) {
        await HandoffSheet.show(
          context,
          mode: HandoffMode.depart,
          destination: HandoffPlace(course.startName, entry.lat, entry.lng),
        );
        if (!context.mounted) return;
      }
    }
    context.go('/radar');
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

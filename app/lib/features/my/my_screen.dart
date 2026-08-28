import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/saves.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';

/// MY-01/03 마이 (SCREENS.md MY-01/03).
///
/// 국도 51선 수집 진행률 → 찜/스쳐간 발견 → 여행기 → 설정.
class MyScreen extends ConsumerStatefulWidget {
  const MyScreen({super.key});
  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  bool _showPassed = false;
  bool _demoMode = true;

  @override
  Widget build(BuildContext context) {
    final saves = ref.watch(savesProvider);
    final tripsAsync = ref.watch(tripsProvider);
    final ids = _showPassed ? saves.passed : saves.liked;
    final spotsAsync = ref.watch(savedSpotsProvider(ids));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // 탭바에 가려지지 않게 여유를 둔다 (pro-rules: 스크롤/고정요소 공존)
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _profile(tripsAsync.value?.length ?? 0, saves.liked.length + saves.passed.length),
            const SizedBox(height: AppSpace.x6),
            _collection(tripsAsync.value ?? const []),
            const SizedBox(height: AppSpace.x8),
            _savedTabs(saves),
            const SizedBox(height: AppSpace.x3),
            _savedList(spotsAsync),
            const SizedBox(height: AppSpace.x8),
            _tripsSection(tripsAsync),
            const SizedBox(height: AppSpace.x8),
            _settings(),
          ],
        ),
      ),
    );
  }

  Widget _profile(int tripCount, int discoveryCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 8, AppSpace.gutter, 0),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: Color(0xFFE4EDEF), shape: BoxShape.circle),
            child: const Icon(Icons.person_outline, size: 24, color: AppColors.ink3),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '여행자',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '여행기 $tripCount편 · 발견 $discoveryCount곳',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 국도 51선 수집 — 유한한 컬렉션이라 진행률이 보인다.
  Widget _collection(List<Trip> trips) {
    final collected = trips.map((t) => t.routeId).toSet().toList()..sort();
    final km = trips.fold<int>(0, (a, t) => a + t.distanceKm);
    final ratio = collected.length / 51;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(17),
          boxShadow: AppShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  S.collectionTitle,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                Text(
                  '${collected.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.routeBlue,
                  ),
                ),
                const Text(
                  ' / 51',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: const Color(0xFFEDF2F3),
                valueColor: const AlwaysStoppedAnimation(AppColors.routeBlue),
              ),
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [for (final r in collected) RouteBadge('$r', size: BadgeSize.sm)],
            ),
            const SizedBox(height: 12),
            Text(
              '지금까지 ${km}km · 완주까지 ${14000 - km}km',
              style: const TextStyle(fontSize: 12, color: AppColors.ink2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedTabs(SavesState saves) {
    Widget tab(String label, int count, bool on, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: on ? null : Border.all(color: AppColors.line2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label $count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : AppColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Row(
        children: [
          tab(
            S.savedTab,
            saves.liked.length,
            !_showPassed,
            () => setState(() => _showPassed = false),
          ),
          const SizedBox(width: 7),
          tab(
            S.passedTab,
            saves.passed.length,
            _showPassed,
            () => setState(() => _showPassed = true),
          ),
        ],
      ),
    );
  }

  Widget _savedList(AsyncValue<List<Spot>> async) {
    return async.maybeWhen(
      orElse: () => const SizedBox(height: 40),
      data: (spots) {
        if (spots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(AppSpace.gutter, 20, AppSpace.gutter, 20),
            child: Text(
              S.savedEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.ink3),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Column(
            children: [
              for (var i = 0; i < spots.length; i++) ...[
                SpotListRow(spot: spots[i], onTap: () => context.push('/spot/${spots[i].id}')),
                if (i != spots.length - 1)
                  const Divider(height: 1, thickness: 1, color: AppColors.line),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _tripsSection(AsyncValue<List<Trip>> async) {
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (trips) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: SectionLabel(S.tripsTitle, trailing: '전체 ${trips.length}편'),
          ),
          const SizedBox(height: AppSpace.x3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: Column(
              children: [
                for (var i = 0; i < trips.length; i++) ...[
                  _TripRow(trip: trips[i]),
                  if (i != trips.length - 1)
                    const Divider(height: 1, thickness: 1, color: AppColors.line),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settings() {
    Widget row(String label, Widget trailing) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
          trailing,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: SectionLabel('설정'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Column(
            children: [
              row('알림 · 음성', const Icon(Icons.chevron_right, size: 18, color: AppColors.ink3)),
              const Divider(height: 1, thickness: 1, color: AppColors.line),
              row(
                '데모 모드',
                Switch(
                  value: _demoMode,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.routeBlue,
                  onChanged: (v) => setState(() => _demoMode = v),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.line),
              row('사진 접근', const Icon(Icons.chevron_right, size: 18, color: AppColors.ink3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final type = trip.stops.isEmpty ? SpotType.attraction : trip.stops.first.type;
    return InkWell(
      onTap: () => context.push('/my/trip/${trip.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SpotImage(
              type: type,
              spotId: trip.stops.isEmpty ? null : trip.stops.first.spotId,
              width: 56,
              height: 56,
              radius: 13,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EP.${trip.episode} ${trip.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.title.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${trip.date} · ${trip.distanceKm}km · 들른 곳 ${trip.visited}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}

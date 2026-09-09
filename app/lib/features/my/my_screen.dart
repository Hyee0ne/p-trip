import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/env.dart';
import '../../core/os.dart';
import '../../core/saves.dart';
import '../../core/proximity_alert.dart';
import '../../core/settings.dart';
import '../../core/trip_log.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/voice.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/heart_button.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/trip_cover.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import 'data_sources_sheet.dart';

/// MY-01/03 마이 (SCREENS.md MY-01/03).
///
/// 국도 51선 수집 진행률 → 찜/스쳐간 발견 → 여행기 → 설정.
class MyScreen extends ConsumerStatefulWidget {
  const MyScreen({super.key});
  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  @override
  Widget build(BuildContext context) {
    final saves = ref.watch(savesProvider);
    // ⚠ 동기로 읽는다. FutureProvider 를 거치면 지운 행이 한 프레임 더 남아 Dismissible 이 죽는다.
    final trips = ref.watch(tripLogProvider).finished;
    final spotsAsync = ref.watch(savedSpotsProvider(savedKey(saves.idsOf(SaveTargetKind.spot))));
    // 코스·노선도 찜 대상이다 (TECH_SPEC §2).
    final coursesAsync = ref.watch(
      savedCoursesProvider(savedKey(saves.idsOf(SaveTargetKind.course))),
    );
    final routesAsync = ref.watch(savedRoutesProvider(savedKey(saves.idsOf(SaveTargetKind.route))));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // 탭바에 가려지지 않게 여유를 둔다 (pro-rules: 스크롤/고정요소 공존)
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _profile(trips.length, saves.liked.length),
            const SizedBox(height: AppSpace.x6),
            _collection(trips),
            const SizedBox(height: AppSpace.x8),
            _savedHeader(saves),
            const SizedBox(height: AppSpace.x3),
            _savedList(spotsAsync),
            _savedCourses(coursesAsync),
            _savedRoutes(routesAsync),
            const SizedBox(height: AppSpace.x8),
            _tripsSection(trips),
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
    // 노선별로 합친다. 한 여행이 여러 국도를 지나면 각자에게 간다 (맵매칭).
    // ⚠ 맵매칭 전에 기록된 여행은 routeKm이 비어 있다 — 그땐 예전 방식으로 센다.
    //   0으로 지우면 이미 달린 길이 사라진다.
    final byRoute = <int, int>{};
    for (final t in trips) {
      if (t.routeKm.isEmpty) {
        byRoute[t.routeId] = (byRoute[t.routeId] ?? 0) + t.distanceKm;
      } else {
        t.routeKm.forEach((r, km) => byRoute[r] = (byRoute[r] ?? 0) + km);
      }
    }
    final collected = byRoute.keys.toList()..sort();
    final km = byRoute.values.fold<int>(0, (a, b) => a + b);
    // 아직 못 받았으면 기획 표기값으로 버틴다. 실측이 오면 그걸 쓴다.
    final totalKm = ref.watch(totalRoadKmProvider).value ?? 14000;
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
              // ⚠ 14000km는 기획 표기다. 실제 선형 합계는 13,910km로 DB에 있다 —
              //   노선이 늘거나 선형이 바뀌면 같이 움직여야 한다.
              '지금까지 ${km}km · 완주까지 ${totalKm - km}km',
              style: const TextStyle(fontSize: 12, color: AppColors.ink2),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠ 탭이 둘이었다 — '찜' / '스쳐간 발견'. 자동 적립을 없애면서 탭도 없앴다 (2026-09-07).
  ///   목록이 하나뿐인데 탭을 남기면 누를 데 없는 UI가 된다.
  Widget _savedHeader(SavesState saves) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
    child: SectionLabel(S.savedTab, trailing: '${saves.liked.length}곳'),
  );

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

  /// 찜한 코스 — 리스트 행. 스팟과 구분되게 노선 뱃지를 앞에 둔다.
  Widget _savedCourses(AsyncValue<List<Course>> async) {
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (courses) {
        if (courses.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x5, AppSpace.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('찜한 코스'),
              const SizedBox(height: AppSpace.x2),
              for (final c in courses)
                InkWell(
                  onTap: () => context.push('/course/${c.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        RouteBadge('${c.routeId}', size: BadgeSize.sm),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title, style: AppType.title.copyWith(fontSize: 14.5)),
                              const SizedBox(height: 2),
                              Text(
                                '${c.startName} → ${c.endName} · ${c.distanceKm}km',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
                              ),
                            ],
                          ),
                        ),
                        HeartButton(target: SaveRef.course(c.id), iconSize: 16),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 찜한 노선 — 코스가 아직 없는 길의 '출시 알림' 대체 (SCREENS.md CO-07).
  Widget _savedRoutes(AsyncValue<List<RouteLine>> async) {
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (routes) {
        if (routes.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x5, AppSpace.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('찜한 국도', trailing: '코스가 열리면 알려드려요'),
              const SizedBox(height: AppSpace.x3),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final r in routes)
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          border: Border.all(color: AppColors.line2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RouteBadge('${r.id}', size: BadgeSize.sm),
                            const SizedBox(width: 8),
                            Text(
                              r.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tripsSection(List<Trip> trips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: SectionLabel(S.tripsTitle, trailing: '전체 ${trips.length}편'),
        ),
        const SizedBox(height: AppSpace.x3),
        if (trips.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 20),
            child: Text(
              S.tripsEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.ink3),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Column(
            children: [
              for (var i = 0; i < trips.length; i++) ...[
                // 왼쪽으로 밀면 지운다 (2026-09-09). 묻지 않고 지우되 토스트로 한 번 되돌릴 수 있다.
                Dismissible(
                  key: ValueKey('trip-${trips[i].id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppColors.marketRed,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 22),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                  ),
                  onDismissed: (_) => _deleteTrip(trips[i]),
                  child: _TripRow(trip: trips[i]),
                ),
                if (i != trips.length - 1)
                  const Divider(height: 1, thickness: 1, color: AppColors.line),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _deleteTrip(Trip trip) {
    final removed = ref.read(tripLogProvider.notifier).delete(trip.id);
    if (removed == null) return;
    showAppToast(
      context,
      S.tripDeleted,
      actionLabel: S.tripUndo,
      onAction: () => ref.read(tripLogProvider.notifier).restore(removed.$1, removed.$2),
    );
  }

  Widget _settings() {
    // ⚠ 화살표(`>`)를 단 행은 **반드시 onTap이 있어야 한다.** 눌러도 아무 일이
    //   없는 행은 애플이 '비활성 UI 요소'로 반려한다.
    Widget row(String label, Widget trailing, {VoidCallback? onTap}) {
      final body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ),
            trailing,
          ],
        ),
      );
      if (onTap == null) return body;
      return InkWell(
        onTap: onTap,
        // 운전 중에도 누르는 화면이다 — 터치 영역을 규격 아래로 줄이지 않는다.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouch.min),
          child: body,
        ),
      );
    }

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
              row(
                '앱을 꺼둬도 알림',
                Switch(
                  value: ref.watch(backgroundAlertsProvider),
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.routeBlue,
                  // ⚠ 끄면 알림만 멈춘다. OS 권한은 그대로 둔다 (SCREENS.md DR-06).
                  //   켤 땐 권한부터 — 권한 없이 켜두면 켠 줄 알고 기다리게 된다.
                  onChanged: (v) async {
                    final n = ref.read(backgroundAlertsProvider.notifier);
                    if (!v) return n.set(false);
                    // 안 물어봤으면 여기서 묻는다. 물어봤는데 꺼져 있으면 iOS 는 다시 못 묻는다 —
                    // 설정 앱으로 보낸다. 켠 줄 알고 기다리게 두지 않는다.
                    final request = ref.read(proximityAlertsProvider).requestPermission;
                    final ok = n.asked ? await request() : await n.askOnce(request);
                    await n.set(ok);
                    if (!ok && mounted) {
                      showAppToast(context, S.toastNotifDenied);
                      await Geolocator.openAppSettings();
                    }
                  },
                ),
              ),
              // ⚠ **데모 모드는 개발 빌드에만 보인다** (2026-08-30, 출시 전환).
              //   출시 앱 설정에 '가짜로 달리는 모드'가 있으면 안 된다.
              //   Env.demoAvailable이 거짓이면 주행은 항상 진짜 GPS다.
              if (Env.demoAvailable) ...[
                if (ref.watch(backgroundAlertsProvider) && ref.watch(demoModeProvider))
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpace.x3),
                    child: Text(
                      S.bgDemoNote,
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.ink3),
                    ),
                  ),
                const Divider(height: 1, thickness: 1, color: AppColors.line),
                row(
                  '데모 모드',
                  Switch(
                    value: ref.watch(demoModeProvider),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.routeBlue,
                    // ⚠ 켜면 모의 주행(코스 선형 배속), 끄면 진짜 GPS.
                    //   다음 출발부터 적용된다 — 달리는 중에 갈아타면 기록이 끊긴다.
                    onChanged: (v) => ref.read(demoModeProvider.notifier).set(v),
                  ),
                ),
              ],
              const Divider(height: 1, thickness: 1, color: AppColors.line),
              row(
                S.photoAccessRow,
                const Icon(Icons.chevron_right, size: 18, color: AppColors.ink3),
                // 권한을 앱에서 바꿀 수는 없다. iOS 설정을 열어주는 게 할 수 있는 전부다.
                onTap: PhotoManager.openSetting,
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.line),
              // ⚠ **기본 음성일 때만** 보인다. 고품질이 있거나 모르면(엔진 실패) 안 그린다 —
              //   눌러도 할 게 없는 행을 남기지 않는다. 앱이 그 설정 화면을 열어줄 수도 없어
              //   경로를 글로 보여주는 게 전부다.
              if (ref.watch(voiceQualityProvider).value == false) ...[
                row(
                  S.voiceBetterRow,
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.ink3),
                  onTap: _showVoiceBetter,
                ),
                const Divider(height: 1, thickness: 1, color: AppColors.line),
              ],
              // ⚠ 공공누리 출처표시 의무. 지우지 말 것 (SCREENS.md MY-01/03).
              row(
                S.sourcesRow,
                const Icon(Icons.chevron_right, size: 18, color: AppColors.ink3),
                onTap: () => DataSourcesSheet.show(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 고품질 음성을 받는 길. 앱이 대신 열어줄 화면이 없어서 경로를 그대로 적는다.
  void _showVoiceBetter() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x5, AppSpace.gutter, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(S.voiceBetterRow, style: AppType.h2),
            const SizedBox(height: AppSpace.x3),
            const Text(
              S.voiceBetterWhy,
              style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.ink2),
            ),
            const SizedBox(height: AppSpace.x4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 한 줄에 화살표로 이어 쓰면 설정 앱을 오가며 따라가기 어렵다. 한 단계 한 줄.
                  for (final (i, step) in S.voiceBetterSteps(iosMajor).indexed)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink3,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.x3),
            const Text(
              S.voiceBetterAfter,
              style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/my/trip/${trip.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            TripCoverThumb(trip: trip),
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

/// 여행기 목록의 썸네일.
///
/// 대표 사진을 고른 여행기는 **그때 내가 찍은 사진**을, 아니면 첫 들른 곳의 스팟 사진을 쓴다.
/// ⚠ 원래는 언제나 '첫 들른 곳'이었다 (2026-09-07 이전). 위치와도, 내 사진과도 무관한
///   그냥 첫 번째였다. 이제 MY-02 사진 스트립에서 직접 고른다.
/// ⚠ 사진첩에서 지워졌으면 **조용히 스팟 사진으로 돌아간다.** 깨진 자리를 남기지 않는다.

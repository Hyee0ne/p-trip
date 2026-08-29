import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/base_camp.dart';
import '../../core/demo.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import 'base_suggest_sheet.dart';

/// CO-06 거점 설정 (SCREENS.md CO-06).
///
/// ⚠ 숙소가 아니라 **위치**를 받는다. 예약·결제 플로우를 만들지 않는다 (원칙 4).
///   후보는 정보 + 외부 링크까지만.
///
/// 진입 경로 2개:
///  - `/course/:id/base` — 코스 경유. 확정 후 CO-02 복귀
///  - `/base` — 역진입. 확정 후 §CO-06b 국도 제안
class BaseScreen extends ConsumerStatefulWidget {
  const BaseScreen({super.key, this.courseId});

  /// null이면 역진입(`/base`).
  final String? courseId;

  @override
  ConsumerState<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends ConsumerState<BaseScreen> {
  String? _pickedName;

  /// ⚠ 좌표를 안 들고 있으면 거점을 정해도 내비가 엉뚱한 데로 간다.
  double? _pickedLat;
  double? _pickedLng;

  bool get _isReentry => widget.courseId == null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          S.baseTitle,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
        titleSpacing: 0,
      ),
      body: Stack(
        children: [
          ListView(
            // 하단 CTA가 목록을 가리지 않게 비운다.
            // ⚠ '건너뛰고 출발'이 붙으면서 CTA가 44pt 높아졌다 — 여백도 같이 커져야 한다.
            padding: EdgeInsets.only(bottom: _isReentry ? 124 : 168),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                child: Text(
                  S.baseIntro,
                  style: TextStyle(fontSize: 13.5, height: 1.7, color: AppColors.ink2),
                ),
              ),
              const SizedBox(height: AppSpace.x4),
              _searchField(),
              const SizedBox(height: AppSpace.x3),
              _mapPicker(),
              const SizedBox(height: AppSpace.x6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                child: SectionLabel(S.baseCandidates, trailing: S.baseCandidatesSub),
              ),
              const SizedBox(height: AppSpace.x3),
              _candidates(),
              const SizedBox(height: AppSpace.x4),
              const Center(
                child: Text(S.baseWithout, style: TextStyle(fontSize: 12.5, color: AppColors.ink3)),
              ),
            ],
          ),
          _cta(),
        ],
      ),
    );
  }

  Widget _searchField() {
    // TODO(M2): 카카오 장소검색 API 연결 (M0.5 키 발급 후)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.line2),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: AppColors.ink3),
            const SizedBox(width: 9),
            Text(
              _pickedName ?? S.baseSearchHint,
              style: TextStyle(
                fontSize: 14.5,
                color: _pickedName == null ? AppColors.ink3 : AppColors.ink,
                fontWeight: _pickedName == null ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠ 여기가 지도를 쓰는 **유일한 화면**이다 — 위치를 직접 골라야 하기 때문.
  /// M0.5 스파이크로 kakao_map_plugin이 검증되면 이 자리를 실제 지도로 교체한다.
  Widget _mapPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.hero),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE8F1EE), Color(0xFFDCEAEC), Color(0xFFCFE3E9)],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: Center(child: Icon(Icons.place, size: 40, color: AppColors.violet)),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xF0FFFFFF),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                boxShadow: AppShadow.card,
              ),
              child: const Text(
                S.basePinOnMap,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _candidates() {
    final async = ref.watch(baseCandidatesProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (spots) {
        if (spots.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Column(
            children: [
              for (var i = 0; i < spots.length; i++) ...[
                _CandidateRow(spot: spots[i], onPick: () => _pick(spots[i])),
                if (i != spots.length - 1)
                  const Divider(height: 1, thickness: 1, color: AppColors.line),
              ],
            ],
          ),
        );
      },
    );
  }

  void _pick(Spot spot) {
    setState(() {
      _pickedName = spot.name;
      _pickedLat = spot.lat;
      _pickedLng = spot.lng;
    });
    showAppToast(context, S.baseToastExternal);
  }

  Widget _cta() {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                onPressed: _confirm,
                child: const Text(
                  S.baseCta,
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            // ⚠ **거점은 선택사항이다** (원칙 4 — 거점은 위치 입력값일 뿐).
            //   이 버튼이 없으면 거점을 안 정한 사람은 출발할 길이 없다.
            //   코스에서 온 경우에만 낸다 — 역진입(/base)은 거점이 목적 그 자체다.
            if (!_isReentry)
              TextButton(
                onPressed: () => context.go('/radar'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppTouch.min),
                  foregroundColor: AppColors.ink2,
                ),
                child: const Text(
                  S.baseSkipAndStart,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_pickedName == null) {
      showAppToast(context, S.baseToastPickFirst);
      return;
    }
    // TODO(M2): 지도 핀으로 직접 찍는 경로. 지금은 후보 목록에서 고른 좌표를 쓴다.
    // ⚠ 좌표가 없으면 **거점으로 삼지 않는다.** 0,0을 넣으면 기니만이 목적지가 된다 —
    //   내비 핸드오프가 대서양으로 안내한다.
    final lat = _pickedLat;
    final lng = _pickedLng;
    if (lat == null || lng == null) {
      showAppToast(context, S.baseToastNoCoord);
      return;
    }
    ref.read(baseCampProvider.notifier).set(BaseCamp(name: _pickedName!, lat: lat, lng: lng));

    if (_isReentry) {
      // 역진입 → CO-06b 국도 제안. 거절해도 아무 일도 일어나지 않는다.
      final tookRoute = await BaseSuggestSheet.show(context, baseName: _pickedName!);
      if (!mounted) return;
      // ⚠ '/course/donghae-sea'로 가고 있었다. **그런 코스는 없다** — 에러 화면이 떴다.
      context.go(tookRoute ? '/course/$kDemoCourseId' : '/');
    } else {
      context.pop();
    }
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.spot, required this.onPick});
  final Spot spot;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SpotImage(
              type: spot.type,
              spotId: spot.id,
              imageUrl: spot.imageUrl,
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
                    spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.title.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spot.blurb,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: AppColors.ink2),
                  ),
                ],
              ),
            ),
            // ⚠ 예약은 외부로만 — 우리는 정보까지 (원칙 4)
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse(
                  'https://search.naver.com/search.naver?query=${Uri.encodeComponent(spot.name)}',
                ),
                mode: LaunchMode.externalApplication,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      S.spotBook,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.routeBlue,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.open_in_new, size: 13, color: AppColors.routeBlue),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

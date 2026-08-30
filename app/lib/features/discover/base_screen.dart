import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/base_camp.dart';
import '../../core/demo.dart';
import '../../core/location.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import 'base_pin_map.dart';
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

  final _search = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<PlaceHit> _hits = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

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
              _searchHits(),
              const SizedBox(height: AppSpace.x3),
              _mapPicker(),
              _pickedRow(),
              const SizedBox(height: AppSpace.x6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                child: SectionLabel(S.baseCandidates, trailing: S.baseCandidatesSub),
              ),
              const SizedBox(height: AppSpace.x3),
              _candidates(),
              _tonightSky(),
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

  /// 진짜 검색창 (SCREENS.md CO-06 3번).
  ///
  /// ⚠ 그전엔 `Text` 위젯이었다. 탭해도 아무 일도 안 났다 —
  ///   후보 목록에 없는 숙소를 잡은 사람은 거점을 정할 방법이 없었다.
  /// ⚠ 키는 Edge Function 뒤에 있다. 앱은 이름·주소·좌표만 받는다.
  Widget _searchField() {
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
            Expanded(
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: _onQuery,
                onSubmitted: (q) => _runSearch(q),
                style: const TextStyle(fontSize: 14.5, color: AppColors.ink),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: S.baseSearchHint,
                  hintStyle: TextStyle(fontSize: 14.5, color: AppColors.ink3),
                ),
              ),
            ),
            if (_searching)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              )
            else if (_search.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _search.clear();
                  setState(() => _hits = const []);
                },
                child: const Icon(Icons.close, size: 16, color: AppColors.ink3),
              ),
          ],
        ),
      ),
    );
  }

  /// 타이핑이 멈춘 뒤에 한 번 부른다. 글자마다 부르면 할당량만 태운다.
  void _onQuery(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _hits = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _searching = true);
    final fix = ref.read(currentLocationProvider).value;
    final hits = await ref
        .read(discoverRepositoryProvider)
        .searchPlaces(q, lat: fix?.lat, lng: fix?.lng);
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

  /// 검색 결과. 없으면 자리를 만들지 않는다.
  Widget _searchHits() {
    if (_hits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x3, AppSpace.gutter, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.line2),
        ),
        child: Column(
          children: [
            for (var i = 0; i < _hits.length && i < 6; i++) ...[
              if (i != 0) const Divider(height: 1, thickness: 1, color: AppColors.line),
              InkWell(
                onTap: () => _pickPlace(_hits[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hits[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            if (_hits[i].addr.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _hits[i].addr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // 거리는 알 때만. 모르면 자리를 비운다 — 0km라고 하지 않는다.
                      if (_hits[i].distanceM != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          S.kmAway(_hits[i].distanceM! / 1000),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pickPlace(PlaceHit p) {
    setState(() {
      _pickedName = p.name;
      _pickedLat = p.lat;
      _pickedLng = p.lng;
      _hits = const [];
    });
    _search.text = p.name;
    FocusScope.of(context).unfocus();
    showAppToast(context, S.baseToastExternal);
  }

  /// 지도로 찍기 — **별도 화면으로 연다** (SCREENS.md CO-06 4번의 '지도에서 핀 찍기' 칩).
  ///
  /// ⚠ 처음엔 이 자리에 작은 지도를 박았는데 **자리가 통째로 비어 나왔다.**
  ///   카카오 지도는 네이티브 플랫폼 뷰라 스크롤 목록 안에서 합성되지 않는다.
  ///   화면을 채우는 CO-07 방식으로 옮겼다 — 가짜 지도를 다시 그리지는 않는다.
  Widget _mapPicker() {
    final picked = _pickedLat != null && _pickedLng != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: SizedBox(
        height: AppTouch.min,
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.line2),
            foregroundColor: AppColors.ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            alignment: Alignment.centerLeft,
          ),
          onPressed: _openPicker,
          icon: const Icon(Icons.map_outlined, size: 18, color: AppColors.violet),
          label: Text(
            picked ? S.basePinChange : S.basePinOnMap,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// 지금 고른 자리. **정했다는 걸 눈으로 보여준다** — 지도에서 찍으면
  /// 검색창에는 아무것도 안 남아서, 이게 없으면 정해졌는지 알 수가 없다.
  Widget _pickedRow() {
    final name = _pickedName;
    if (name == null || _pickedLat == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x3, AppSpace.gutter, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.tintViolet,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            const Icon(Icons.place, size: 17, color: AppColors.violet),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onTintViolet,
                ),
              ),
            ),
            // 좌표를 보여준다 — 지도에서 찍은 자리는 이름이 없으니 이게 유일한 확인이다.
            Text(
              '${_pickedLat!.toStringAsFixed(4)}, ${_pickedLng!.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B5292)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker() async {
    final fix = ref.read(currentLocationProvider).value;
    final start = _pickedLat != null && _pickedLng != null
        ? (_pickedLat!, _pickedLng!)
        : (fix != null && fix.hasFix ? (fix.lat!, fix.lng!) : null);
    final at = await BasePinPicker.open(context, center: start);
    if (at == null || !mounted) return;
    setState(() {
      _pickedLat = at.$1;
      _pickedLng = at.$2;
      // 지도에서 찍은 자리는 이름이 없다. 지어내지 않고 그렇게 적는다.
      _pickedName = S.basePickedOnMap;
    });
    showAppToast(context, S.baseToastExternal);
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

  /// 오늘 밤 하늘 (SCREENS.md CO-06 8번, TECH_SPEC §3.8).
  ///
  /// ⚠ **핀을 찍은 뒤에만.** 어디서 잘지 정해지지 않았는데 그날 밤 이야기를 할 수 없다.
  /// ⚠ SCREENS 예시는 "달이 01:20에 집니다"인데 **그 값을 낼 수 없다** —
  ///   데이터의 moonset은 그날 아침에 진 달이라 짝이 맞지 않는다 (20260829190000 참고).
  ///   낼 수 있는 사실만 말한다. 없으면 줄을 그리지 않는다.
  Widget _tonightSky() {
    final lat = _pickedLat;
    final lng = _pickedLng;
    if (lat == null || lng == null) return const SizedBox.shrink();
    final sky = ref.watch(nightSkyProvider((lat: lat, lng: lng, date: DateTime.now()))).value;
    final line = sky?.tonightLine;
    if (line == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x5, AppSpace.gutter, 0),
      child: Row(
        children: [
          const Icon(Icons.nightlight_outlined, size: 15, color: AppColors.ink3),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              line,
              style: const TextStyle(fontSize: 13.5, height: 1.6, color: AppColors.ink2),
            ),
          ),
        ],
      ),
    );
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
      final tookRoute = await BaseSuggestSheet.show(
        context,
        ref,
        baseName: _pickedName!,
        baseLat: lat,
        baseLng: lng,
      );
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

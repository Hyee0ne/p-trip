import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/saves.dart';
import '../../core/theme.dart';
import '../../core/widgets/heart_button.dart';
import '../../core/widgets/route_badge.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';

/// 「한 곳씩」 스토리 덱 (SCREENS.md CO-01 A).
///
/// - **좌우 스와이프**로 넘긴다. 홈은 탭 루트라 iOS 뒤로가기 제스처와 겹치지 않는다.
/// - 상단 인디케이터가 차오르고, 다 차면 **자동으로 다음 카드**.
/// - ⚠ 넘긴 카드는 **아무것도 기록하지 않는다.** 앉아서 훑어본 걸
///   '스쳐간 발견'에 넣으면 이동 기록이 오염된다 (그건 DR-02의 몫).
class StoryDeck extends ConsumerStatefulWidget {
  const StoryDeck({super.key, required this.cards});

  final List<CurationCard> cards;

  /// 카드 한 장이 머무는 시간. 읽을 거리가 있어 스토리(5초)보다 길게 잡는다.
  static const dwell = Duration(seconds: 7);

  @override
  ConsumerState<StoryDeck> createState() => _StoryDeckState();
}

class _StoryDeckState extends ConsumerState<StoryDeck> with SingleTickerProviderStateMixin {
  late final PageController _page = PageController();
  late final AnimationController _timer =
      AnimationController(vsync: this, duration: StoryDeck.dwell)..addStatusListener((s) {
        if (s != AnimationStatus.completed) return;
        if (!_visible) {
          _timer.stop();
          return;
        }
        _next();
      });

  int _index = 0;
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _timer.forward();
  }

  /// 지금 이 화면이 실제로 보이고 있는가.
  ///
  /// ⚠ 두 겹으로 확인해야 한다:
  ///  - [TickerMode] — 다른 **탭**에 있을 때 (셸이 IndexedStack이라 화면이 살아 있다)
  ///  - [ModalRoute.isCurrent] — 같은 탭에서 다른 화면을 **위에 띄웠을** 때
  /// 하나라도 빠지면 안 보이는 화면의 타이머가 계속 돈다.
  bool get _visible =>
      mounted &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visible) {
      _timer.stop();
    } else if (!_held && !_timer.isAnimating) {
      _timer.forward();
    }
  }

  @override
  void dispose() {
    _timer.dispose();
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (!_visible) return;
    final last = widget.cards.length - 1;
    if (_index >= last) {
      _page.jumpToPage(0); // 덱을 한 바퀴 돌면 처음으로
    } else {
      _page.nextPage(duration: AppMotion.slow, curve: AppMotion.curve);
    }
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _timer.reset();
    if (_visible && !_held) _timer.forward();
  }

  /// 길게 누르면 멈춘다 — 읽는 중에 넘어가지 않게 (스토리 관습).
  void _hold(bool down) {
    setState(() => _held = down);
    down ? _timer.stop() : _timer.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Progress(count: widget.cards.length, index: _index, anim: _timer),
        Expanded(
          child: GestureDetector(
            onLongPressDown: (_) => _hold(true),
            onLongPressUp: () => _hold(false),
            onLongPressCancel: () => _hold(false),
            child: PageView.builder(
              controller: _page,
              onPageChanged: _onPageChanged,
              itemCount: widget.cards.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                child: _Card(card: widget.cards[i]),
              ),
            ),
          ),
        ),
        _Actions(card: widget.cards[_index]),
      ],
    );
  }
}

/// 차오르는 진행 막대 — 지금 카드가 얼마나 남았는지 보인다.
class _Progress extends StatelessWidget {
  const _Progress({required this.count, required this.index, required this.anim});

  final int count;
  final int index;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 10, AppSpace.gutter, 12),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    children: [
                      const ColoredBox(color: AppColors.line2, child: SizedBox.expand()),
                      if (i < index)
                        const ColoredBox(color: AppColors.ink, child: SizedBox.expand())
                      else if (i == index)
                        AnimatedBuilder(
                          animation: anim,
                          builder: (_, _) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: anim.value,
                            child: const ColoredBox(color: AppColors.ink, child: SizedBox.expand()),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (i != count - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card});
  final CurationCard card;

  static const _accent = {
    CardAccent.today: AppColors.marketRed,
    CardAccent.rising: AppColors.sun,
    CardAccent.tracks: AppColors.violet,
    CardAccent.route: AppColors.routeBlue,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(card.detailRoute),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SpotImage(type: card.type, spotId: card.imageKey, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xF215100B),
                    Color(0xB315100B),
                    Color(0x2615100B),
                    Color(0x0015100B),
                  ],
                  stops: [0, 0.28, 0.56, 0.78],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _kicker(),
                  const SizedBox(height: 12),
                  Text(
                    card.title,
                    style: AppType.h1.copyWith(
                      fontSize: 27,
                      height: 1.24,
                      letterSpacing: -1.1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    card.body,
                    style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xEBFFFFFF)),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      RouteBadge('${card.routeId}', size: BadgeSize.sm),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          card.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xD9FFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 흰 알약 + 시의성 색 점 — 무슨 종류의 제안인지 색으로 먼저 알린다.
  Widget _kicker() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent[card.kickerColor] ?? AppColors.routeBlue,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            card.kicker,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF15100B),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 액션 2개 — 찜, 그리고 글자가 있는 주 버튼.
///
/// ⚠ 원형 아이콘 3개는 **운전 중(DR-02) 문법**이다. 여기선 읽을 수 있으니
///   글자가 있는 버튼을 쓴다. 길안내는 없다 — 아직 출발 전이다.
class _Actions extends StatelessWidget {
  const _Actions({required this.card});
  final CurationCard card;

  @override
  Widget build(BuildContext context) {
    // ⚠ 카드 종류와 상관없이 담을 수 있다. 스팟만 되던 건 구현 한계였지
    //   설계가 아니었다 (TECH_SPEC §2 saves.spot_id | course_id).
    final target = switch (card) {
      SpotCurationCard(:final spot) => SaveRef.spot(spot.id),
      CourseCurationCard(:final course) => SaveRef.course(course.id),
      RouteCurationCard(:final line) => SaveRef.route(line.id),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 14, AppSpace.gutter, 10),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line2),
              boxShadow: AppShadow.card,
            ),
            child: Center(
              child: HeartButton(
                target: target,
                iconSize: 21,
                tapSize: 52,
                color: AppColors.marketRed,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.routeBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                onPressed: () => context.go(card.route),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      card.ctaLabel,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/route_badge.dart';

/// ON 온보딩 3장 (SCREENS.md §ON) — 컨셉 · 어떻게 쓰나 · 가면서 알아요 (A안, 2026-09-09).
///
/// ⚠ 국도 번호 상식('홀수는 남북…')과 권한 카드 두 장을 뺐다. 사용법이 아니었고,
///   권한은 여기서 묻지 않는다 — 위치는 출발할 때(DR-00), 알림은 처음 달린 뒤(DR-06).
///   ~~3장 하단에 그 순서를 예고하는 한 줄~~ → 뺐다 (2026-09-13). 권한 얘기는 물을 때 한다.
/// 로그인을 여기서 강제하지 않는다 — guest로 진입할 수 있다. 건너뛰기는 항상 보인다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _controller.nextPage(duration: AppMotion.slow, curve: AppMotion.curve);
    } else {
      _finish();
    }
  }

  /// 시작하기·건너뛰기 — 둘 다 '봤다'로 적고 홈으로. 다음 실행부터는 안 뜬다.
  void _finish() {
    unawaited(Onboarding.markDone());
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  S.onboardSkip,
                  style: TextStyle(color: AppColors.ink3, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [_Concept(), _HowTo(), _Ahead()],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final on = i == _page;
                return AnimatedContainer(
                  duration: AppMotion.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: on ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: on ? AppColors.ink : AppColors.line2,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.x5,
                AppSpace.gutter,
                AppSpace.x6,
              ),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.routeBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(
                    _page == 2 ? S.onboardStart : S.onboardNext,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.x6),
    child: Center(child: child),
  );
}

/// 1장 · 컨셉. 문구는 홈의 히어로와 같다.
class _Concept extends StatelessWidget {
  const _Concept();
  @override
  Widget build(BuildContext context) {
    return _Page(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RouteBadge('7', size: BadgeSize.lg),
          const SizedBox(height: AppSpace.x8),
          Text(
            '${S.heroLine1}\n${S.heroLine2}',
            textAlign: TextAlign.center,
            style: AppType.h1.copyWith(fontSize: 28, height: 1.44),
          ),
          const SizedBox(height: AppSpace.x4),
          const Text(
            S.onboardSub,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: AppColors.ink2),
          ),
        ],
      ),
    );
  }
}

/// 2장 · 어떻게 쓰나 — 길 → 방향 → 출발. 앱의 실제 부품(뱃지·방향 버튼)으로 말한다.
class _HowTo extends StatelessWidget {
  const _HowTo();
  @override
  Widget build(BuildContext context) {
    return _Page(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.onboardHowTitle,
            textAlign: TextAlign.center,
            style: AppType.h1.copyWith(fontSize: 24, height: 1.4),
          ),
          const SizedBox(height: AppSpace.x6),
          const _StepRow(
            leading: RouteBadge('7', size: BadgeSize.md),
            title: S.onboardStep1,
            sub: S.onboardStep1Sub,
          ),
          const _StepRow(leading: _DirectionPill(), title: S.onboardStep2, sub: S.onboardStep2Sub),
          const _StepRow(
            leading: _RadarPill(),
            title: S.onboardStep3,
            sub: S.onboardStep3Sub,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.leading,
    required this.title,
    required this.sub,
    this.last = false,
  });
  final Widget leading;
  final String title;
  final String sub;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: last ? 0 : AppSpace.x3),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          SizedBox(width: 92, child: Center(child: leading)),
          const SizedBox(width: AppSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.title),
                const SizedBox(height: 2),
                Text(sub, style: AppType.caption.copyWith(color: AppColors.ink2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 출발 시트(CO-08)의 방향 버튼을 축소한 것. 문구도 그 버튼 그대로다.
class _DirectionPill extends StatelessWidget {
  const _DirectionPill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.routeBlue,
      borderRadius: BorderRadius.circular(AppRadius.chip),
    ),
    child: const Text(
      '${S.departNorth} ↑',
      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
    ),
  );
}

class _RadarPill extends StatelessWidget {
  const _RadarPill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.fieldGreen, width: 1.5),
      borderRadius: BorderRadius.circular(AppRadius.chip),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.radar, size: 15, color: AppColors.fieldGreen),
        SizedBox(width: 4),
        Text(
          S.onboardStep3Pill,
          style: TextStyle(
            color: AppColors.fieldGreen,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

/// 3장 · 가면서 알아요 — 발견 카드(DR-02)의 축소 예시 + 두 줄 (소리 · 알림 흔적).
///
/// 카드 아래 두 줄은 **내비를 앞에 둔 채 달리는 사람**에게 이 앱이 어떻게 닿는지다 (2026-09-13 보강).
/// 소리로 먼저 오고, 놓쳐도 알림에 남아 눌러 되돌아갈 수 있다. 권한 예고 줄은 뺐다 — 물을 때 말한다.
class _Ahead extends StatelessWidget {
  const _Ahead();
  @override
  Widget build(BuildContext context) {
    return _Page(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.onboardAheadTitle,
            textAlign: TextAlign.center,
            style: AppType.h1.copyWith(fontSize: 22, height: 1.4),
          ),
          const SizedBox(height: AppSpace.x5),
          const _ExampleCard(),
          const SizedBox(height: AppSpace.x5),
          const _AheadRow(Icons.volume_up_outlined, S.onboardAheadVoice),
          const _AheadRow(Icons.notifications_none, S.onboardAheadTrace),
        ],
      ),
    );
  }
}

/// 카드 아래 한 줄. 아이콘은 그 줄이 말하는 채널(소리·알림·위치)이다.
class _AheadRow extends StatelessWidget {
  const _AheadRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: AppColors.routeBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// 발견 카드 예시. **실존 장소(북평민속오일장)**, 실제 문구 함수, 사진 없음, 「예시」 표시.
/// ⚠ 목업 데이터가 아니라 카드의 **형식**을 보여주는 것이다 — 사진을 넣지 않는 이유다.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5B6F72), Color(0xFF2B3A3C), Color(0xFF141C1C)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.sun,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: const Text(
                S.onboardExample,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xF5FFFFFF),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.marketRed,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  S.cardSituation(S.cardNearbyLead, 2),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15100B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            S.cardMarketDay(S.onboardExampleSpot),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            S.onboardExampleBody,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xD9FFFFFF)),
          ),
          const SizedBox(height: 14),
          // 세 동작에 이름을 단다 — 실제 카드는 아이콘뿐이지만, 처음 보는 사람에겐 뭘 하는 버튼인지가 정보다.
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniAction(Icons.close, 34, label: S.onboardActSkip),
              SizedBox(width: 18),
              _MiniAction(Icons.near_me, 46, filled: true, label: S.cardVisit),
              SizedBox(width: 18),
              _MiniAction(Icons.favorite_border, 34, label: S.onboardActSave),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction(this.icon, this.size, {this.filled = false, required this.label});
  final IconData icon;
  final double size;
  final bool filled;
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    child: Column(
      children: [
        // 가운데(들르기)가 크다. 작은 둘은 위를 맞춰 라벨 줄이 한 줄에 놓이게 아래로 내린다.
        SizedBox(height: filled ? 0 : 6),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.white : const Color(0x2EFFFFFF),
            border: filled ? null : Border.all(color: const Color(0x80FFFFFF), width: 1.5),
          ),
          child: Icon(icon, size: size * 0.46, color: filled ? AppColors.ink : Colors.white),
        ),
        SizedBox(height: filled ? 6 : 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xE0FFFFFF),
          ),
        ),
      ],
    ),
  );
}

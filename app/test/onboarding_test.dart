import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/settings.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/features/onboarding/onboarding_screen.dart';
import 'package:p_trip/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ON 온보딩은 **최초 1회** 떠야 한다 (SCREENS.md §ON).
///
/// 2026-09-09 실기기 리포트: 출시 앱에서 온보딩이 한 번도 안 떴다. `/onboarding` 라우트만 있고
/// 첫 실행에 거기로 보내는 코드가 없었다. 이 테스트가 게이트를 잠근다.
void main() {
  // ⚠ 홈에 도착하면 계속 도는 그림이 있어 pumpAndSettle 이 영영 안 끝난다 — 고정 프레임으로 기다린다.
  Future<void> settle(WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('첫 실행이면 온보딩, 본 뒤엔 홈', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await Onboarding.initialLocation(), '/onboarding');
    await Onboarding.markDone();
    expect(await Onboarding.initialLocation(), '/');
  });

  testWidgets('첫 실행 — 온보딩 3장이 뜨고, 「시작하기」로 홈에 가면 다시 안 뜬다', (tester) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(child: PTripApp(initialLocation: await Onboarding.initialLocation())),
    );
    await settle(tester, 4);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.textContaining(S.heroLine1), findsOneWidget, reason: '1장 컨셉');

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text(S.onboard2), findsOneWidget, reason: '2장 국도 읽는 법');

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text(S.onboardLocation), findsOneWidget, reason: '3장 권한 — 위치');
    expect(find.text(S.onboardNotif), findsOneWidget, reason: '3장 권한 — 알림');
    expect(find.text('사진'), findsNothing, reason: '사진 권한 항목은 지웠다');

    await tester.tap(find.text('시작하기'));
    await settle(tester, 8);
    expect(find.byType(OnboardingScreen), findsNothing, reason: '홈으로 갔다');
    expect(await Onboarding.isDone(), isTrue, reason: '봤다고 적혔다');
    expect(await Onboarding.initialLocation(), '/', reason: '다음 실행은 홈');
    expect(tester.takeException(), isNull);
  });

  testWidgets('「건너뛰기」도 본 것으로 적는다 — 다시 보여주는 게 재촉이다', (tester) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: PTripApp(initialLocation: '/onboarding')));
    await settle(tester, 4);
    await tester.tap(find.text('건너뛰기'));
    await settle(tester, 8);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(await Onboarding.isDone(), isTrue);
  });
}

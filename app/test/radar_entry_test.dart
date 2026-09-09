import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/drive.dart';
import 'package:p_trip/core/journey.dart';
import 'package:p_trip/core/settings.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/radar/radar_screen.dart';
import 'package:p_trip/features/radar/radar_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 레이더 진입 (SCREENS.md DR-01 진입, 2026-09-08).
///
/// **레이더는 길을 골라 출발해야 돌고, 내비 앱을 고른 순간부터 돈다.**
/// 그전엔 화면은 보여도 위치도 서버도 건드리지 않는다.
class _NoDemo extends DemoModeNotifier {
  @override
  bool build() => false;
}

class _WithJourney extends StartedJourney {
  @override
  Journey? build() => const Journey(
    routeId: 7,
    routeName: '동해 바닷길',
    path: [GeoPoint(37.45, 129.17), GeoPoint(37.75, 128.90)],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle(WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('길을 안 골랐으면 아무것도 돌지 않는다 — 고르러 가는 버튼만', (tester) async {
    phone(tester);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: RadarScreen())));
    await settle(tester, 8);

    expect(find.text(S.radarIdleTitle), findsOneWidget);
    expect(find.text(S.radarIdleCta), findsOneWidget);
    expect(find.byType(RadarView), findsOneWidget, reason: '그림은 돈다 — 죽은 화면처럼 보이면 안 된다');
    final c = ProviderScope.containerOf(tester.element(find.byType(RadarScreen)));
    expect(c.read(driveProvider).running, isFalse, reason: '그림만 돈다 — 위치도 서버도 안 건드린다');
    expect(find.text(S.radarScanning), findsNothing);
    expect(find.text(S.radarFinish), findsNothing, reason: '마칠 여행이 없다');
    expect(tester.takeException(), isNull);
  });

  testWidgets('길을 골랐으면 핸드오프 시트가 먼저 — 내리면 「내비로 안내받기」', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 데모는 시트 없이 바로 돈다. 실주행 경로를 본다.
          demoModeProvider.overrideWith(_NoDemo.new),
          startedJourneyProvider.overrideWith(_WithJourney.new),
        ],
        child: const MaterialApp(home: RadarScreen()),
      ),
    );
    // 진입 때 위치를 최대 3초 기다린 뒤 시트를 띄운다.
    await settle(tester, 48);

    expect(find.text(S.handoffTitleRoute(7)), findsOneWidget, reason: '레이더 위에 핸드오프 시트');
    expect(find.text(S.handoffTmap), findsOneWidget);
    expect(find.text(S.handoffApple), findsOneWidget);
    expect(find.text(S.radarFinish), findsNothing, reason: '고르기 전엔 마칠 여행이 없다');

    // 안 고르고 내린다 (바깥 탭). '안내 없이' 버튼은 없다 — 내리는 게 곧 그것이다.
    await tester.tapAt(const Offset(10, 10));
    await settle(tester, 6);

    expect(find.text(S.handoffTitleRoute(7)), findsNothing);
    expect(find.text(S.radarHandoffAgain), findsOneWidget, reason: '시트를 다시 여는 유일한 길');
    expect(find.text(S.radarFinish), findsNothing, reason: '여전히 안 켜졌다');
    expect(tester.takeException(), isNull);
  });
}

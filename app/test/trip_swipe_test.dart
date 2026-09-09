import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/core/theme.dart';
import 'package:p_trip/core/trip_log.dart';
import 'package:p_trip/features/my/my_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MY-01 여행기 행 삭제 — **밀면 버튼이 드러나고, 눌러야 지워진다** (2026-09-09 개정).
///
/// 전엔 끝까지 밀면 바로 지워졌다. 밀기는 쉬운 제스처라 스치듯 한 번에 지워졌다 (실기기 리포트).
/// NN/g: 파괴적 동작 앞엔 삭제 버튼 하나만큼의 확인을 둔다. 되돌리기는 그 다음 보조다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const w = 393.0;

  Future<ProviderContainer> pumpWithTrip(WidgetTester tester) async {
    tester.view.physicalSize = const Size(w * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = ProviderContainer();
    addTearDown(c.dispose);
    final log = c.read(tripLogProvider.notifier);
    log.start(routeId: 7, routeName: '동해 바닷길', startName: '삼척', endName: '강릉');
    log.updateDistance(65);
    log.end();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: MyScreen()),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    return c;
  }

  Finder row() => find.byType(Slidable);
  Finder deleteBtn() => find.text(S.tripDeleteAction);
  // 닫혀 있으면 버튼을 아예 안 그린다(flutter_slidable). 그려졌더라도 화면 밖이면 안 드러난 것이다.
  bool onScreen(WidgetTester tester, Finder f) =>
      f.evaluate().isNotEmpty && tester.getTopLeft(f).dx < w;

  testWidgets('밀면 「삭제」가 드러나고 멈춘다 — 끝까지 밀어도 지워지지 않는다', (tester) async {
    await pumpWithTrip(tester);
    expect(row(), findsOneWidget);
    expect(find.textContaining('EP.1'), findsOneWidget);
    expect(onScreen(tester, deleteBtn()), isFalse, reason: '닫혀 있을 땐 버튼이 화면 밖이다');

    // 화면 너비만큼 — 옛 Dismissible 이면 여기서 지워졌다.
    await tester.drag(row(), const Offset(-w, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('EP.1'), findsOneWidget, reason: '밀기만으로는 안 지워진다');
    expect(find.text(S.tripDeleted), findsNothing);
    expect(onScreen(tester, deleteBtn()), isTrue, reason: '버튼이 드러나 있다');
    expect(tester.takeException(), isNull);
  });

  testWidgets('드러난 「삭제」를 눌러야 지워진다 — 그 뒤 되돌리기', (tester) async {
    final c = await pumpWithTrip(tester);
    await tester.drag(row(), const Offset(-160, 0));
    await tester.pumpAndSettle();

    await tester.tap(deleteBtn());
    // 토스트가 올라오는 동안은 포인터를 무시한다 — 다 올라올 때까지 기다린다.
    await tester.pumpAndSettle();
    expect(find.textContaining('EP.1'), findsNothing, reason: '눌렀으니 지워졌다');
    expect(c.read(tripLogProvider).finished, isEmpty);
    expect(find.text(S.tripDeleted), findsOneWidget, reason: '지웠다는 토스트');

    await tester.tap(find.text(S.tripUndo));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.read(tripLogProvider).finished, hasLength(1), reason: '되돌렸다');
    expect(find.textContaining('EP.1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // 토스트 타이머
    expect(tester.takeException(), isNull);
  });
}

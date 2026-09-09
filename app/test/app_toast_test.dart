import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/widgets/app_toast.dart';

/// 토스트는 **스스로 사라져야 한다** (SCREENS.md §0.2 — 단일 스타일, 짧게).
///
/// 실기기 리포트(2026-09-09): 「여행기를 지웠어요 · 되돌리기」가 4초 뒤에도 남아 있었다.
/// Flutter 3.41 부터 액션이 달린 스낵바는 `persist` 가 기본 참이라 시간이 지나도 안 닫힌다.
/// 이 테스트가 그걸 잠근다 — `persist: false` 를 빼면 여기서 터진다.
void main() {
  Future<void> pumpHost(WidgetTester tester, {required bool action}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => action
                    ? showAppToast(context, '지웠어요', actionLabel: '되돌리기', onAction: () {})
                    : showAppToast(context, '담았어요'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('되돌리기가 달린 토스트도 4초 뒤엔 스스로 사라진다', (tester) async {
    await pumpHost(tester, action: true);
    expect(find.text('지웠어요'), findsOneWidget);
    expect(find.text('되돌리기'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('지웠어요'), findsOneWidget, reason: '아직 되돌릴 수 있는 시간이다');

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text('지웠어요'), findsNothing, reason: '4초가 지나면 닫힌다 — 영영 떠 있는 배너가 아니다');
  });

  testWidgets('액션 없는 토스트는 1.9초 뒤 사라진다', (tester) async {
    await pumpHost(tester, action: false);
    expect(find.text('담았어요'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();
    expect(find.text('담았어요'), findsNothing);
  });
}

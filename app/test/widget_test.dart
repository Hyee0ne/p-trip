import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:p_trip/main.dart';
import 'package:p_trip/core/strings.dart';

void main() {
  testWidgets('3탭 셸이 뜨고 발견 탭이 기본 선택된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PTripApp()));
    await tester.pumpAndSettle();

    // 탭바 3개 (SCREENS.md §0.2)
    expect(find.text(S.tabDiscover), findsOneWidget);
    expect(find.text(S.tabRadar), findsOneWidget);
    expect(find.text(S.tabMy), findsOneWidget);

    // 초기 라우트는 CO-01 홈
    expect(find.text('CO-01'), findsOneWidget);
  });

  testWidgets('레이더 탭으로 전환하면 DR-01이 뜬다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PTripApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.tabRadar));
    await tester.pumpAndSettle();

    expect(find.text('DR-01'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/main.dart';

/// 발견 탭 화면 간 이동이 실제로 되는지 — 라우트 선언만으로는 안 잡히는 것.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: PTripApp()));
    await tester.pumpAndSettle();
  }

  Future<void> toBrowse(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('홈 → 국도 선택(CO-07): 51선 그리드와 주행 불가 노선 문구', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);

    await tester.tap(find.text('전체 51'));
    await tester.pumpAndSettle();

    expect(find.text(S.routesTitle), findsOneWidget);
    // 북한 구간은 별명 대신 고정 문구 (SCREENS.md CO-07)
    expect(find.text(S.routeUndrivable), findsOneWidget);
  });

  testWidgets('국도 선택 → 코스 상세(CO-02): ETA 없이 순수 주행시간만', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await tester.tap(find.text('전체 51'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('동해 바닷길'));
    await tester.pumpAndSettle();

    expect(find.text('순수 주행시간'), findsOneWidget);
    // 스탯 숫자는 RichText(값+단위)로 그려서 findRichText가 필요하다
    expect(find.text('2:10', findRichText: true), findsOneWidget);
    expect(find.text('86km', findRichText: true), findsOneWidget);
    expect(find.text(S.courseStart), findsOneWidget);
    // 거점 미설정 배너
    expect(find.text(S.baseNone), findsOneWidget);
  });

  testWidgets('코스 상세는 뷰 모드를 따른다 — 훑어보기면 발견이 번호 목록으로', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await tester.tap(find.text('전체 51'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동해 바닷길'));
    await tester.pumpAndSettle();

    expect(find.text(S.courseDiscoveries), findsOneWidget);
    expect(find.text(S.courseOrder), findsOneWidget);
    // 4곳이 한 화면에 (아홉 번 넘기지 않는다)
    expect(find.text('북평 5일장'), findsWidgets);
    expect(find.text('묵호등대'), findsWidgets);
  });

  testWidgets('스팟 상세(CO-03): 확신도 문구가 있고 별점은 없다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);

    await tester.tap(find.text('북평 5일장').first);
    await tester.pumpAndSettle();

    expect(find.text(S.trustNotice), findsOneWidget);
    expect(find.text(S.trustCall), findsOneWidget);
    expect(find.text(S.trustReviews), findsOneWidget);
    expect(find.text(S.spotNavigate), findsOneWidget);
    // ⚠ 원칙 3 — 별점 위젯이 존재하면 안 된다
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_half), findsNothing);
  });

  testWidgets('검색(SR)은 별도 화면 — 토글이 사라지고 탭바를 덮는다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);

    await tester.tap(find.text(S.searchHint));
    await tester.pumpAndSettle();

    // 신호 3: 토글 없음 + 탭바 덮음
    expect(find.text(S.viewBrowse), findsNothing);
    expect(find.text(S.tabRadar), findsNothing);
    // 입력 전 화면
    expect(find.text(S.searchRecent), findsOneWidget);
    expect(find.text(S.searchSuggest), findsOneWidget);
  });

  testWidgets('검색어를 넣으면 결과가 리스트로 나온다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await tester.tap(find.text(S.searchHint));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '물회');
    await tester.pumpAndSettle();

    expect(find.text('1곳'), findsOneWidget);
    expect(find.text('어달마을 물회 골목'), findsOneWidget);
  });

  testWidgets('없는 걸 검색하면 억지로 채우지 않는다', (tester) async {
    await pumpApp(tester);
    await toBrowse(tester);
    await tester.tap(find.text(S.searchHint));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '스키장');
    await tester.pumpAndSettle();

    expect(find.text(S.searchEmpty('스키장')), findsOneWidget);
    expect(find.text('북평 5일장'), findsNothing);
  });
}

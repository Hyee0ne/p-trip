import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/saves.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/data/repositories/fixture_discover_repository.dart';
import 'package:p_trip/features/radar/radar_view.dart';
import 'package:p_trip/main.dart';

void main() {
  /// ⚠ 홈의 스토리 덱은 7초마다 자동으로 넘어간다 — 끝나지 않는 애니메이션이라
  ///   `pumpAndSettle`을 쓰면 영원히 안 끝난다. 프레임을 몇 개만 돌린다.
  Future<void> settleHome(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PTripApp()));
    await settleHome(tester);
  }

  testWidgets('3탭 셸이 뜨고 발견 탭이 기본 선택된다', (tester) async {
    await pumpApp(tester);
    expect(find.text(S.tabDiscover), findsOneWidget);
    expect(find.text(S.tabRadar), findsOneWidget);
    expect(find.text(S.tabMy), findsOneWidget);
    expect(find.text(S.appName), findsOneWidget);
  });

  /// ⚠ 레이더는 **길을 골라 출발해야** 돈다 (2026-09-08, SCREENS.md DR-01 진입).
  ///   탭만 눌렀을 땐 아무것도 돌지 않고, 고르러 가는 버튼만 있다.
  testWidgets('레이더 탭 — 길을 안 골랐으면 돌지 않고 고르러 가라고 한다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(S.tabRadar));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.text(S.radarIdleTitle), findsOneWidget);
    expect(find.text(S.radarIdleCta), findsOneWidget);
    expect(find.byType(RadarView), findsOneWidget, reason: '그림은 돈다 (장식) — 실제 주행은 아니다');
    expect(find.text(S.radarScanning), findsNothing);
    // ⚠ 레이더에는 뷰 토글이 없다 — 운전 중엔 언제나 한 곳씩
    expect(find.text(S.viewBrowse), findsNothing);
    expect(find.text(S.viewOneByOne), findsNothing);
  });

  testWidgets('홈이 지도다 — 길부터 고른다', (tester) async {
    await pumpApp(tester);
    for (var n = 0; n < 14; n++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    // ⚠ 옛 홈(스토리 덱·훑어보기 토글)은 지웠다. 목적지가 아니라 **길**을 고르는 게
    //   이 앱의 진입 문법이라 지도가 첫 화면이다 (2026-08-30 재설계).
    expect(find.text(S.routesNearTitle), findsOneWidget);

    // 검색은 지도 위에 떠 있다 — 시트를 끌어올려야 보이면 안 된다
    expect(find.text(S.searchHint), findsOneWidget);
  });

  test('국도는 51선이고 남북 27 · 동서 24로 갈린다', () async {
    const repo = FixtureDiscoverRepository();
    final routes = await repo.routes();

    expect(routes.length, 51, reason: '국도 51선');
    expect(routes.where((r) => r.axis == 'NS').length, 27, reason: '남북(홀수)');
    expect(routes.where((r) => r.axis == 'EW').length, 24, reason: '동서(짝수)');

    // 홀수=남북, 짝수=동서는 규칙이다
    for (final r in routes) {
      expect(r.axis, r.id.isOdd ? 'NS' : 'EW', reason: '${r.id}번');
    }
    // 번호 중복 없음
    expect(routes.map((r) => r.id).toSet().length, 51);
  });

  test('찜은 스팟·코스·노선을 모두 담는다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(savesProvider.notifier);

    expect(n.toggleLike(const SaveRef.spot('bukpyeong-market')), isTrue);
    expect(n.toggleLike(const SaveRef.course('donghae-sea')), isTrue);
    expect(n.toggleLike(SaveRef.route(44)), isTrue);

    final s = c.read(savesProvider);
    expect(s.liked.length, 3);
    expect(s.idsOf(SaveTargetKind.spot), {'bukpyeong-market'});
    expect(s.idsOf(SaveTargetKind.course), {'donghae-sea'});
    expect(s.idsOf(SaveTargetKind.route), {'44'});

    // 같은 id라도 종류가 다르면 다른 항목이다
    expect(c.read(savesProvider).isLiked(const SaveRef.spot('donghae-sea')), isFalse);

    // 토글하면 빠진다
    expect(n.toggleLike(const SaveRef.course('donghae-sea')), isFalse);
    expect(c.read(savesProvider).idsOf(SaveTargetKind.course), isEmpty);
  });

  /// ⚠ '스쳐간 발견' 자동 적립을 없앴다 (2026-09-07). 담는 건 사용자뿐이다 —
  ///   담은 적 없는 목록이 불어나면서 정작 찜을 밀어냈다.
  test('담는 방법은 찜 하나뿐이다 — 자동으로 쌓이는 목록은 없다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(savesProvider.notifier);

    n.toggleLike(const SaveRef.spot('chuam-chotdae'));
    expect(c.read(savesProvider).liked, {'spot:chuam-chotdae'});

    // 상태에 들어 있는 집합은 liked 하나다.
    expect(c.read(savesProvider).idsOf(SaveTargetKind.spot), {'chuam-chotdae'});
  });
}

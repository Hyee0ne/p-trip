import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/data/models/models.dart';
import 'package:p_trip/features/radar/catchup_sheet.dart';

/// DR-03 몰아보기. 새 위젯이라 **레이아웃이 넘치는지**가 제일 걱정이다 —
/// 오버플로는 테스트에서 예외로 잡힌다.
void main() {
  Discovery d(String id, String name, String blurb) => Discovery(
    spot: Spot(
      id: id,
      name: name,
      type: SpotType.market,
      routeId: 7,
      detourMin: 4,
      trustScore: 85,
      blurb: blurb,
    ),
    headline: name,
    situation: '근처에 있어요 · 국도에서 4분',
    body: blurb,
  );

  testWidgets('스쳐간 곳들이 가로로 늘어서고 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CatchupSheet(
              passed: [
                d('a', '북평민속오일장', '동해시 오일장길에 서는 3·8일 장'),
                d('b', '추암 촛대바위', '기암괴석이 늘어선 해변, 일출 명소로 이름났다'),
                d('c', '아주 긴 이름을 가진 어떤 관광지 기념관 전시관', '설명이 아주 길어서 두 줄을 넘길 수도 있는 그런 문장이다'),
              ],
              onDone: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text(S.catchupTitle), findsOneWidget);
    expect(find.text('북평민속오일장'), findsOneWidget);
    expect(find.text(S.catchupGo), findsWidgets);

    // ⚠ "되돌아가기" 류 유도 문구를 쓰지 않는다 (SCREENS DR-03).
    expect(find.textContaining('되돌아'), findsNothing);
    expect(find.textContaining('돌아가'), findsNothing);
  });
}

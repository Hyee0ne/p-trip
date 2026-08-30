import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/base_camp.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/data/models/models.dart';

/// CO-02 거점 배너가 쓰는 **상태와 문구의 계약**.
///
/// ⚠ 배너 위젯 자체를 그려보지는 않는다 — 그건 화면에서 눈으로 봐야 한다.
///   여기서 지키는 건 '정하면 provider가 바뀐다'와 '승인된 카피를 쓴다' 둘이다.
/// ⚠ 그전엔 배너가 상태를 아예 안 읽어서, 거점을 정하고 돌아와도 '정해주세요'였다.
void main() {
  testWidgets('거점을 정하면 배너가 읽을 상태와 문구가 준비된다', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    // 정하기 전
    expect(c.read(baseCampProvider), isNull);

    c
        .read(baseCampProvider.notifier)
        .set(const BaseCamp(name: '묵호항 게스트하우스', lat: 37.55, lng: 129.09));

    final base = c.read(baseCampProvider);
    expect(base, isNotNull);
    // 배너가 쓰는 문구가 승인된 카피인지
    expect(S.baseSet(base!.name), '오늘 밤 거점: 묵호항 게스트하우스');
    expect(S.baseSetSub, isNotEmpty);
  });
}

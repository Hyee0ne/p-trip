import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/env.dart';

/// 출시 빌드에 **'가짜로 달리는 모드'가 없어야 한다** (2026-08-30 출시 전환).
///
/// ⚠ 테스트는 debug로 돌아서 `demoAvailable`이 참이다. 여기서 지키는 건
///   "release에서는 DEMO_BUILD를 명시해야만 열린다"는 규칙 자체다.
///   실제 차단은 `flutter build ios --release`로 만든 번들에서 확인한다.
void main() {
  test('개발 빌드에서는 데모를 쓸 수 있다', () {
    expect(Env.demoAvailable, isTrue, reason: '테스트는 debug 모드다');
  });

  test('데모를 못 쓰는 빌드면 demoUsable도 거짓이다', () {
    // demoUsable = demoAvailable && demoDefault. 둘 중 하나만 꺼져도 실주행이다.
    expect(Env.demoUsable, Env.demoAvailable && Env.demoDefault);
  });
}

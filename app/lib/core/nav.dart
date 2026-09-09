import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 출발 → 레이더. **발견 탭은 뿌리('/')로 돌려놓고 간다.**
///
/// 출발은 발견 탭의 시트(CO-08)나 코스 화면(CO-07)에서 일어난다. 둘 다 발견 탭의
/// 내비게이터 위에 얹힌 것이라, `go('/radar')` 로 탭만 바꾸면 **그 자리에 그대로 남는다** —
/// 여행을 마치고 발견 탭에 돌아오면 「길 떠나기」 시트가 버튼 비활성인 채 기다리고 있었다
/// (2026-09-09 실기기). 그래서 먼저 발견 탭의 스택을 뿌리까지 내린 다음 레이더로 간다.
///
/// ⚠ `go('/')` 뒤에 바로 `go('/radar')` 를 부르면 안 된다. go 는 비동기 트랜잭션이라
///   마지막 것만 살고, 그마저 **옛 구성**을 바탕으로 계산돼 스택이 안 내려간다.
///   내비게이터를 직접 내리는 건 동기라 그 뒤의 go 가 내려간 스택을 본다.
void departToRadar(BuildContext context) {
  final router = GoRouter.of(context);
  // 시트든 코스 페이지든, 발견 탭 내비게이터의 첫 화면('/')까지 내린다.
  Navigator.of(context).popUntil((r) => r.isFirst);
  router.go('/radar');
}

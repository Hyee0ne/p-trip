import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 뷰 모드 — SCREENS.md §0.1 글로벌 상태.
///
/// CO-01 홈과 CO-02 코스 상세가 공유하고 마지막 선택을 기억한다.
/// ⚠ 레이더(DR-*)에는 뷰 모드가 없다. 언제나 [oneByOne].
enum ViewMode {
  /// 전면 카드 하나씩. 기본값.
  oneByOne,

  /// 2열 그리드 + 검색창 + 필터 칩.
  browse,
}

// TODO(M2): SharedPreferences로 앱 재실행 후에도 마지막 선택 유지
final viewModeProvider = NotifierProvider<ViewModeNotifier, ViewMode>(ViewModeNotifier.new);

class ViewModeNotifier extends Notifier<ViewMode> {
  @override
  ViewMode build() => ViewMode.oneByOne;

  void toggle() => state = state == ViewMode.oneByOne ? ViewMode.browse : ViewMode.oneByOne;

  void set(ViewMode mode) => state = mode;
}

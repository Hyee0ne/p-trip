import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 찜 · 스쳐간 발견 (TECH_SPEC §2 saves).
///
/// `like` = 사용자가 직접 담은 것. `passed` = 스쳐간 발견(레이더가 자동 적립).
/// ⚠ 둘은 다른 사건이다. DR-05 동승자 모드의 '넘기기'는 passed로 적립하지 않는다.
enum SaveKind { like, passed }

class SavesState {
  const SavesState({this.liked = const {}, this.passed = const {}});

  final Set<String> liked;
  final Set<String> passed;

  bool isLiked(String spotId) => liked.contains(spotId);
  bool isPassed(String spotId) => passed.contains(spotId);

  SavesState copyWith({Set<String>? liked, Set<String>? passed}) =>
      SavesState(liked: liked ?? this.liked, passed: passed ?? this.passed);
}

// TODO(M2): SharedPreferences 저장 → 로그인 시 Supabase saves 테이블과 동기화
final savesProvider = NotifierProvider<SavesNotifier, SavesState>(SavesNotifier.new);

class SavesNotifier extends Notifier<SavesState> {
  @override
  SavesState build() => const SavesState();

  /// 하트 토글. 담았으면 true를 반환한다 (토스트 표시 여부 판단용).
  bool toggleLike(String spotId) {
    final next = {...state.liked};
    final added = next.add(spotId);
    if (!added) next.remove(spotId);
    state = state.copyWith(liked: next);
    return added;
  }

  /// 스쳐간 발견 자동 적립. 이미 찜한 곳은 passed로 내리지 않는다.
  void markPassed(String spotId) {
    if (state.liked.contains(spotId)) return;
    state = state.copyWith(passed: {...state.passed, spotId});
  }

  void clearPassed(String spotId) =>
      state = state.copyWith(passed: {...state.passed}..remove(spotId));
}

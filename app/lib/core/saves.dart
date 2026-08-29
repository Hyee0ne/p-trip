import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 찜 · 스쳐간 발견 (TECH_SPEC §2 saves).
///
/// `like` = 사용자가 직접 담은 것. `passed` = 스쳐간 발견(레이더가 자동 적립).
/// ⚠ 둘은 다른 사건이다. 홈에서 카드를 넘긴 건 passed가 아니다 (SCREENS.md CO-01 A).
enum SaveKind { like, passed }

/// 찜 대상 종류. 스펙상 스팟만이 아니라 **코스·노선도 담을 수 있다.**
/// (TECH_SPEC §2 `saves.spot_id | course_id`, SCREENS.md CO-07 "출시 알림 대체")
enum SaveTargetKind { spot, course, route }

/// 찜 대상 한 건. 저장 키는 `"spot:bukpyeong-market"` 꼴로 인코딩한다.
class SaveRef {
  const SaveRef(this.kind, this.id);
  const SaveRef.spot(this.id) : kind = SaveTargetKind.spot;
  const SaveRef.course(this.id) : kind = SaveTargetKind.course;
  SaveRef.route(int routeId) : kind = SaveTargetKind.route, id = '$routeId';

  final SaveTargetKind kind;
  final String id;

  String get key => '${kind.name}:$id';

  static SaveRef parse(String key) {
    final i = key.indexOf(':');
    final k = SaveTargetKind.values.firstWhere(
      (e) => e.name == key.substring(0, i),
      orElse: () => SaveTargetKind.spot,
    );
    return SaveRef(k, key.substring(i + 1));
  }

  @override
  bool operator ==(Object other) => other is SaveRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

class SavesState {
  const SavesState({this.liked = const {}, this.passed = const {}});

  /// 인코딩된 키 집합.
  final Set<String> liked;
  final Set<String> passed;

  bool isLiked(SaveRef ref) => liked.contains(ref.key);
  bool isPassed(String spotId) => passed.contains(SaveRef.spot(spotId).key);

  /// 종류별로 걸러 원본 id만 돌려준다 (마이 탭 목록용).
  Set<String> idsOf(SaveTargetKind kind, {bool passedOnly = false}) => (passedOnly ? passed : liked)
      .map(SaveRef.parse)
      .where((r) => r.kind == kind)
      .map((r) => r.id)
      .toSet();

  SavesState copyWith({Set<String>? liked, Set<String>? passed}) =>
      SavesState(liked: liked ?? this.liked, passed: passed ?? this.passed);
}

/// 찜·스쳐간 발견은 **기기 안에** 둔다.
///
/// ⚠ 로그인을 넣지 않기로 했다 (2026-08-29). 이유:
///   - 기획이 "로그인 없이 시작"을 전제한다. 온보딩도 권한만 묻는다
///   - 여행기는 본질적으로 그 기기의 기록이다 — `trip_photos`가 기기 안 사진의
///     식별자만 갖는 구조라, 서버에 여행기만 올라가면 사진 없는 반쪽이 된다
///   - 계정을 붙이는 건 MVP 다음이다. **DB 스키마와 RLS는 그대로 둔다** —
///     나중에 계정이 생기면 그때 이 로컬 값을 올려 동기화하면 된다
final savesProvider = NotifierProvider<SavesNotifier, SavesState>(SavesNotifier.new);

const _kLiked = 'saves.liked';
const _kPassed = 'saves.passed';

class SavesNotifier extends Notifier<SavesState> {
  SharedPreferences? _prefs;

  @override
  SavesState build() {
    // 저장소를 여는 동안에도 화면은 떠 있어야 한다. 비운 채로 시작하고 채워 넣는다.
    unawaited(_restore());
    return const SavesState();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      state = SavesState(
        liked: (p.getStringList(_kLiked) ?? const []).toSet(),
        passed: (p.getStringList(_kPassed) ?? const []).toSet(),
      );
    } catch (_) {
      // 저장소를 못 열어도(테스트 환경 등) 앱은 돌아야 한다. 이번 실행에만 안 남을 뿐이다.
    }
  }

  void _persist() {
    final p = _prefs;
    if (p == null) return;
    p.setStringList(_kLiked, state.liked.toList());
    p.setStringList(_kPassed, state.passed.toList());
  }

  /// 하트 토글. 담았으면 true (토스트 표시 여부 판단용).
  bool toggleLike(SaveRef ref) {
    final next = {...state.liked};
    final added = next.add(ref.key);
    if (!added) next.remove(ref.key);
    state = state.copyWith(liked: next);
    _persist();
    return added;
  }

  /// 스쳐간 발견 자동 적립 (DR-02 전용). 이미 찜한 곳은 passed로 내리지 않는다.
  void markPassed(String spotId) {
    final k = SaveRef.spot(spotId).key;
    if (state.liked.contains(k)) return;
    state = state.copyWith(passed: {...state.passed, k});
    _persist();
  }

  void clearPassed(String spotId) {
    state = state.copyWith(passed: {...state.passed}..remove(SaveRef.spot(spotId).key));
    _persist();
  }
}

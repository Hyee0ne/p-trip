import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 지금 달리기로 한 코스의 id.
///
/// 발견 탭에서 [출발]을 누른 순간 정해지고, 레이더가 이걸 보고 주행·기록을 만든다.
///
/// ⚠ **기기에 저장하지 않는다.** 여정은 그 순간의 일이고, 앱이 죽어도 남아야 하는 건
///   여행 기록(core/trip_log.dart)이지 "지금 뭘 달리는 중인지"가 아니다.
/// ⚠ 비어 있으면 레이더가 데모 코스로 돈다 — 레이더 탭을 바로 눌러도 뭔가 보여야 한다.
final startedCourseIdProvider = NotifierProvider<StartedCourseId, String?>(StartedCourseId.new);

class StartedCourseId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

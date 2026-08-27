import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 오늘 밤 거점 — SCREENS.md §0.1 글로벌 상태.
///
/// ⚠ 거점은 **숙소가 아니라 위치 입력값**이다 (CLAUDE.md 원칙 4).
/// 어디서 예약했든 상관없고, 우리는 좌표만 받는다. 예약·결제 플로우를 만들지 않는다.
class BaseCamp {
  const BaseCamp({required this.name, required this.lat, required this.lng});
  final String name;
  final double lat;
  final double lng;
}

final baseCampProvider = NotifierProvider<BaseCampNotifier, BaseCamp?>(BaseCampNotifier.new);

class BaseCampNotifier extends Notifier<BaseCamp?> {
  @override
  BaseCamp? build() => null;

  void set(BaseCamp base) => state = base;
  void clear() => state = null;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/core/drive.dart';
import 'package:p_trip/core/strings.dart';
import 'package:p_trip/features/radar/radar_screen.dart';

/// 위치를 거절한 사람이 보는 화면 (DR-00).
///
/// ⚠ 시뮬레이터로는 확인할 수 없다 — simctl에 "허용 안 함"을 누르는 방법이 없고
///   `privacy revoke`는 거절이 아니라 '다시 묻기'로 돌린다. 그래서 여기서 잡는다.
class _StuckDrive extends DriveNotifier {
  @override
  DriveState build() => const DriveState(needsLocation: true);
}

void main() {
  testWidgets('위치를 못 받으면 이유를 말하고, 막지 않는다', (tester) async {
    tester.view.physicalSize = const Size(375, 667) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [driveProvider.overrideWith(_StuckDrive.new)],
        child: const MaterialApp(home: RadarScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(S.radarNeedsLocation), findsOneWidget);
    // 길이 둘 다 열려 있어야 한다 — 설정으로 가거나, 데모로 보거나.
    expect(find.text(S.radarOpenSettings), findsOneWidget);
    expect(find.text(S.radarUseDemo), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '좁은 화면에서 오버플로');
  });
}

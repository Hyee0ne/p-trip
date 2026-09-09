import 'package:flutter/foundation.dart';

/// 앱에 주입되는 환경변수.
///
/// 실행: `flutter run --dart-define-from-file=dart_defines.json`
/// (`dart_defines.example.json`을 복사해 값을 채운다. `.gitignore`에 걸려 있다.)
///
/// ⚠ 여기 들어가는 건 **앱에 노출돼도 되는 키만**이다.
/// TourAPI 키·Supabase service_role·카카오모빌리티 REST 키는 Edge Function 뒤에 둔다.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  // ⚠ 카카오 키(KAKAO_NATIVE_APP_KEY·KAKAO_JS_APP_KEY)는 지웠다 (2026-09-09).
  //   지도는 Apple MapKit, 내비는 티맵 URL 스킴 — 서드파티 키가 하나도 없다.

  /// 개발용 — 앱을 특정 화면에서 시작시킨다.
  /// `flutter run --dart-define=START_AT=/radar`
  /// 스크린샷 촬영과 시연 리허설에 쓴다. 비어 있으면 '/'.
  static const startAt = String.fromEnvironment('START_AT', defaultValue: '/');

  /// START_AT 을 **명시했는지.** 명시했으면 온보딩 게이트를 건너뛴다 — 화면 확인용 주입이
  /// 첫 실행 온보딩에 막히면 안 된다 (`Onboarding.initialLocation`).
  static const startAtSet = bool.hasEnvironment('START_AT');

  /// 개발·시연 주입 — 위치를 고정한다. `--dart-define=FAKE_LOCATION=37.5245,129.1143`
  /// (동해시. 데모 구간 7번 국도 위) 실기기 없이 CO-07 지도를 확인할 때 쓴다.
  /// ⚠ 값이 있으면 geolocator를 아예 호출하지 않는다 — 권한 팝업도 안 뜬다.
  static const _fakeLocation = String.fromEnvironment('FAKE_LOCATION');

  /// 파싱된 위/경도. 형식이 틀리면 null (조용히 실제 위치로 떨어진다).
  static (double, double)? get fakeLocation {
    final parts = _fakeLocation.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    return (lat == null || lng == null) ? null : (lat, lng);
  }

  /// CO-07 바텀시트를 펼친 채로 시작한다. `--dart-define=SHEET_AT=expanded`
  /// START_AT·AUTO_CARD와 같은 용도 — 스크린샷과 시연 리허설.
  static const sheetExpanded = String.fromEnvironment('SHEET_AT') == 'expanded';

  /// 모의 주행 배속. `--dart-define=DRIVE_SCALE=10` (기본 20 = 1초에 20초 주행).
  /// 데모 코스 65km가 기본값으로 약 3분 걸린다. 리허설 속도를 여기서 맞춘다.
  /// ⚠ Dart에 `double.fromEnvironment`는 없다. int로 받아 변환한다.
  /// 시작하자마자 그 노선의 「길 떠나기」 시트를 연다. `--dart-define=DEPART_AT=7`
  /// 시연 리허설과 화면 캡처용 — START_AT·SHEET_AT과 같은 용도다.
  static const departAt = int.fromEnvironment('DEPART_AT');

  /// **모의 주행을 쓸 수 있는 빌드인가.**
  ///
  /// ⚠ 출시 빌드에는 '가짜로 달리는 모드'가 있으면 안 된다 (2026-08-30 출시 전환).
  ///   개발·프로파일 빌드에서만 켜지고, release에서는 `DEMO=true`를 명시해야 열린다 —
  ///   공모전 시연은 그 플래그를 준 release 빌드로 만든다.
  static const demoAvailable = !kReleaseMode || _demoForced;
  static const _demoForced = bool.fromEnvironment('DEMO_BUILD');

  /// 데모 모드 초깃값. 시연 리허설에서 실주행 경로를 확인할 때
  /// `--dart-define=DEMO=false`로 껐다 켠다. 저장된 설정이 있으면 그쪽이 이긴다.
  static const demoDefault = bool.fromEnvironment('DEMO', defaultValue: true);

  /// 실제로 모의 주행을 할 것인가. **쓸 수 없는 빌드면 무조건 실주행이다.**
  static bool get demoUsable => demoAvailable && demoDefault;

  static const driveScale = int.fromEnvironment('DRIVE_SCALE', defaultValue: 20) * 1.0;

  /// 레이더 발견 카드를 자동으로 띄울지. 스크린샷·시연 중 수동 제어용.
  /// `--dart-define=AUTO_CARD=false`
  static const autoCard = String.fromEnvironment('AUTO_CARD', defaultValue: 'true') != 'false';

  /// 필수 키가 다 들어왔는지. main()에서 확인해 조기에 실패시킨다.
  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static List<String> get missing => [
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
  ];
}

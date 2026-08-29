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
  static const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

  /// ⚠ 더 이상 쓰지 않는다. 지도는 네이티브 SDK로 전환했다 (2026-08-29).
  ///   웹 지도를 다시 붙일 일이 생기면 그때 되살린다.
  static const kakaoJsAppKey = String.fromEnvironment('KAKAO_JS_APP_KEY');

  /// 개발용 — 앱을 특정 화면에서 시작시킨다.
  /// `flutter run --dart-define=START_AT=/radar`
  /// 스크린샷 촬영과 시연 리허설에 쓴다. 비어 있으면 '/'.
  static const startAt = String.fromEnvironment('START_AT', defaultValue: '/');

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
  static const driveScale = int.fromEnvironment('DRIVE_SCALE', defaultValue: 20) * 1.0;

  /// 레이더를 동승자 모드로 시작한다. `--dart-define=RADAR_MODE=passenger`
  /// START_AT·SHEET_AT과 같은 용도 — 스크린샷과 시연 리허설.
  static const radarPassenger = String.fromEnvironment('RADAR_MODE') == 'passenger';

  /// 카카오 지도 키가 붙었는지. 없으면 CO-07은 지도 자리를 비워둔다.
  ///
  /// ⚠ 2026-08-29 네이티브 SDK(kakao_map_sdk)로 전환하면서 **네이티브 앱 키**를 본다.
  ///   지도와 내비 핸드오프가 같은 키를 쓴다. JS 키는 더 이상 쓰지 않는다.
  static bool get hasMapKey => kakaoNativeAppKey.isNotEmpty;

  /// 레이더 발견 카드를 자동으로 띄울지. 스크린샷·시연 중 수동 제어용.
  /// `--dart-define=AUTO_CARD=false`
  static const autoCard = String.fromEnvironment('AUTO_CARD', defaultValue: 'true') != 'false';

  /// 필수 키가 다 들어왔는지. main()에서 확인해 조기에 실패시킨다.
  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static List<String> get missing => [
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    if (kakaoNativeAppKey.isEmpty) 'KAKAO_NATIVE_APP_KEY',
  ];
}

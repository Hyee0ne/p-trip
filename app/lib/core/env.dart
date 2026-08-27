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
  static const kakaoNativeAppKey =
      String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  static const kakaoJsAppKey = String.fromEnvironment('KAKAO_JS_APP_KEY');

  /// 필수 키가 다 들어왔는지. main()에서 확인해 조기에 실패시킨다.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static List<String> get missing => [
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
        if (kakaoNativeAppKey.isEmpty) 'KAKAO_NATIVE_APP_KEY',
      ];
}

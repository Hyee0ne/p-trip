import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/router.dart';
import 'core/strings.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase — 키가 없으면 초기화하지 않는다. 그 경우 앱은 픽스처로 돈다
  // (위젯 테스트가 키 없이 돌아야 해서 이 분기가 필요하다).
  if (Env.isConfigured) {
    await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  }

  // 카카오 지도(네이티브 앱 키). 없으면 초기화하지 않는다 —
  // CO-07은 키가 없으면 지도 자리를 비워둔다 (route_map.dart).
  // ⚠ 내비 핸드오프는 티맵 URL 스킴이라 키가 필요 없다 (카카오내비 SDK 삭제, 2026-09-09).
  if (Env.hasMapKey) {
    unawaited(KakaoMapSdk.instance.initialize(Env.kakaoNativeAppKey));
  }

  runApp(const ProviderScope(child: PTripApp()));
}

class PTripApp extends StatefulWidget {
  const PTripApp({super.key});

  @override
  State<PTripApp> createState() => _PTripAppState();
}

class _PTripAppState extends State<PTripApp> {
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}

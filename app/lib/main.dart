import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'core/env.dart';
import 'core/router.dart';
import 'core/strings.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO(M0): Supabase.initialize — 키는 --dart-define으로 주입 (.env.example 참조)

  // 카카오 지도(네이티브 앱 키). 없으면 초기화하지 않는다 —
  // CO-07은 키가 없으면 지도 자리를 비워둔다 (route_map.dart).
  // ⚠ 지도와 내비 핸드오프가 같은 키를 쓴다.
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

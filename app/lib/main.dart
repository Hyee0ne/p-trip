import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import 'core/env.dart';
import 'core/router.dart';
import 'core/strings.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO(M0): Supabase.initialize — 키는 --dart-define으로 주입 (.env.example 참조)

  // 카카오 지도(JavaScript 키). 없으면 초기화하지 않는다 —
  // CO-07은 키가 없으면 지도 자리를 비워둔다 (route_map.dart).
  if (Env.hasMapKey) {
    AuthRepository.initialize(appKey: Env.kakaoJsAppKey);
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

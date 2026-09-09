import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/cover_store.dart';
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

  // ⚠ 지도는 Apple MapKit, 내비는 티맵 URL 스킴 — 둘 다 키가 없다 (카카오 SDK 전부 삭제, 2026-09-09).

  // 사진첩에서 고른 대표 사진의 보관함. 문서 폴더를 한 번 잡아 둔다.
  await CoverStore.init();

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

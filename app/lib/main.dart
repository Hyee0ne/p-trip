import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/cover_store.dart';
import 'core/env.dart';
import 'core/proximity_alert.dart';
import 'core/router.dart';
import 'core/settings.dart';
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

  // 첫 실행이면 온보딩(ON)으로. ⚠ 2026-09-09 까지 라우트만 있고 **아무도 거기로 안 갔다** —
  //   출시 앱에서 온보딩이 한 번도 안 떴다. 플래그는 prefs 에 있고, 여기서 동기로 읽어 라우터에 준다.
  final start = await Onboarding.initialLocation();

  runApp(ProviderScope(child: PTripApp(initialLocation: start)));
}

class PTripApp extends StatefulWidget {
  const PTripApp({super.key, this.initialLocation});

  /// 시작 화면. null 이면 `Env.startAt`. main 이 온보딩 여부로 정해 넘긴다.
  final String? initialLocation;

  @override
  State<PTripApp> createState() => _PTripAppState();
}

class _PTripAppState extends State<PTripApp> {
  late final _router = buildRouter(initialLocation: widget.initialLocation);

  @override
  void initState() {
    super.initState();
    // 알림 탭 → 그 스팟 상세 (DR-06, 2026-09-13). 라우터가 생긴 뒤에 꽂는다 —
    // 앱이 알림으로 켜진 경우도 attach 가 잡는다. 첫 프레임 뒤에 옮겨야 라우터가 붙어 있다.
    unawaited(
      ProximityAlerts.instance.attach(
        (id) => WidgetsBinding.instance.addPostFrameCallback((_) => _router.go('/spot/$id')),
      ),
    );
  }

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

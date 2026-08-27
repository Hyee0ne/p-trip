import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/strings.dart';
import 'core/theme.dart';

void main() {
  // TODO(M0): Supabase.initialize — 키는 --dart-define으로 주입 (.env.example 참조)
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

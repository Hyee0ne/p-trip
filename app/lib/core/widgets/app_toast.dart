import 'package:flutter/material.dart';
import '../theme.dart';

/// 토스트 — 하단 중앙, 1.9초, 단문. **성공/안내 구분 없이 단일 스타일** (SCREENS.md §0.2).
///
/// 실패도 담담하게 같은 모양으로 뜬다. 재촉 금지 원칙의 일부다.
void showAppToast(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.clearSnackBars();
  m.showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      duration: AppMotion.toast,
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xEE15201F),
      elevation: 0,
      width: null,
      margin: const EdgeInsets.fromLTRB(60, 0, 60, 96),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
    ),
  );
}

import 'package:flutter/material.dart';
import '../theme.dart';

/// 토스트 — 하단 중앙, 1.9초, 단문. **성공/안내 구분 없이 단일 스타일** (SCREENS.md §0.2).
///
/// 실패도 담담하게 같은 모양으로 뜬다. 재촉 금지 원칙의 일부다.
///
/// [actionLabel] 이 있으면 오른쪽에 글자 버튼 하나 (예: 「되돌리기」). 그땐 조금 더 머문다.
void showAppToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final m = ScaffoldMessenger.of(context);
  m.clearSnackBars();
  final hasAction = actionLabel != null && onAction != null;
  m.showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: hasAction ? TextAlign.left : TextAlign.center,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      action: hasAction
          ? SnackBarAction(
              label: actionLabel,
              textColor: const Color(0xFFFFD48A),
              onPressed: onAction,
            )
          : null,
      duration: hasAction ? const Duration(seconds: 4) : AppMotion.toast,
      // ⚠ Flutter 3.41 부터 액션이 달린 스낵바는 `persist` 가 기본 참이라 **시간이 지나도 안 닫힌다**
      //   (실기기 리포트 2026-09-09: 「여행기를 지웠어요」가 4초 뒤에도 남아 있었다).
      //   되돌리기는 4초 안에 누르라는 창이지 영영 떠 있을 배너가 아니다 — 명시적으로 끈다.
      persist: false,
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xEE15201F),
      elevation: 0,
      width: null,
      margin: hasAction
          ? const EdgeInsets.fromLTRB(24, 0, 24, 96)
          : const EdgeInsets.fromLTRB(60, 0, 60, 96),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
    ),
  );
}

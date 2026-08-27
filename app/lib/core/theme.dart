import 'package:flutter/material.dart';

/// P의 여행 디자인 토큰 — 단일 소스.
///
/// 값의 출처는 `docs/P의여행_시안_C보완.html`의 `:root` 블록이다.
/// 시안을 고치면 여기도 같이 고칠 것. 위젯에 raw hex를 쓰지 않는다.
class AppColors {
  AppColors._();

  // ── 브랜드 고정색 (CLAUDE.md, 변경 금지) ──
  /// 국도 표지판 파랑. RouteBadge와 주 버튼.
  static const routeBlue = Color(0xFF1D4ED8);

  /// 뷰포인트 · 확정 상태.
  static const fieldGreen = Color(0xFF3E7C4F);

  /// 장터 · '오늘만'.
  static const marketRed = Color(0xFFC2452D);

  /// 밥집 · 일몰.
  static const sun = Color(0xFFE8A13D);

  /// 거점 전용. 스팟 유형색이 아니라 다른 층위다.
  static const violet = Color(0xFF6D4AA8);

  // ── 라이트 표면 ──
  static const bg = Color(0xFFF6FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF15201F);
  static const ink2 = Color(0xFF5E6E70);
  static const ink3 = Color(0xFF9AA7A8);
  static const line = Color(0xFFE7EEEF);
  static const line2 = Color(0xFFD6E2E4);
  static const fill = Color(0xFFEFF3F4);

  // ── 다크 (레이더 전용) — 푸른 검정이 아니라 따뜻한 숯 ──
  static const darkBg = Color(0xFF12100D);
  static const darkSurface = Color(0xFF241F19);
  static const darkInk = Color(0xFFF0EDE6);
  static const darkInk2 = Color(0xFFB4ADA2);
  static const darkInk3 = Color(0xFF7D766B);
  static const darkLine = Color(0x22F0EDE6);

  // ── 유형 틴트 (칩 배경) ──
  static const tintRed = Color(0xFFFBECE8);
  static const onTintRed = Color(0xFFAC3B22);
  static const tintGreen = Color(0xFFEAF3EC);
  static const onTintGreen = Color(0xFF2E6640);
  static const tintSun = Color(0xFFFBF2E1);
  static const onTintSun = Color(0xFF95640E);
  static const tintViolet = Color(0xFFF6F2FC);
  static const onTintViolet = Color(0xFF4A2E7A);
}

/// 간격 — 4의 배수 리듬.
class AppSpace {
  AppSpace._();
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x12 = 48.0;

  /// 화면 좌우 기본 여백.
  static const gutter = 20.0;
}

class AppRadius {
  AppRadius._();
  static const chip = 999.0;
  static const card = 15.0;
  static const button = 16.0;
  static const sheet = 22.0;
  static const hero = 24.0;
}

/// 터치 영역 — 운전 중 조작이 있으므로 일반 앱보다 크다.
class AppTouch {
  AppTouch._();
  static const min = 44.0;

  /// DR-02 전면 카드의 주 액션(들르기).
  static const drivePrimary = 82.0;

  /// DR-02 전면 카드의 보조 액션(넘기기·찜).
  static const driveSecondary = 60.0;
}

/// 모션 — 재촉하지 않는 톤. 150~300ms.
class AppMotion {
  AppMotion._();
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 300);
  static const curve = Cubic(0.16, 1, 0.3, 1);

  /// 레이더 스윕 1회전.
  static const radarSweep = Duration(seconds: 5);

  /// 토스트 노출 시간 (SCREENS.md §0.2).
  static const toast = Duration(milliseconds: 1900);
}

class AppShadow {
  AppShadow._();
  static const card = [
    BoxShadow(color: Color(0x0D1E4650), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x141E4650), blurRadius: 22, offset: Offset(0, 8)),
  ];
  static const float = [BoxShadow(color: Color(0x2E143238), blurRadius: 30, offset: Offset(0, 10))];
}

/// 타입 스케일. 폰트 패밀리는 Pretendard(고딕) 하나.
/// ⚠ 여행기에도 명조를 쓰지 않는다 (2026-08-27 결정).
class AppType {
  AppType._();
  static const family = 'Pretendard';

  /// DR-02 전면 카드 제목. 운전 중 한눈에 읽혀야 한다.
  static const drive = TextStyle(
    fontSize: 33,
    fontWeight: FontWeight.w800,
    height: 1.24,
    letterSpacing: -1.3,
  );
  static const h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.36,
    letterSpacing: -0.9,
  );
  static const h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.4,
    letterSpacing: -0.6,
  );
  static const title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: -0.3,
  );
  static const body = TextStyle(fontSize: 15, height: 1.6);

  /// DR-02 본문 최소 크기. 이보다 작게 쓰지 않는다.
  static const driveBody = TextStyle(fontSize: 15.5, height: 1.6);
  static const caption = TextStyle(fontSize: 12.5, height: 1.5);

  /// 섹션 라벨 — 대문자 자간.
  static const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4);
}

ThemeData buildAppTheme() {
  // ⚠ fontFamily는 ThemeData 생성자에 직접 준다. copyWith엔 이 인자가 없어서
  //   textTheme.apply만으로는 일부 위젯에 Pretendard가 안 걸린다.
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppType.family,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.routeBlue,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.marketRed,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: AppType.family,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    splashFactory: InkRipple.splashFactory,
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    // Material 기본 스위치가 시안과 안 맞아 톤만 맞춘다
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? AppColors.routeBlue : const Color(0xFFD6E2E4),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

ThemeData buildRadarTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppType.family,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.routeBlue,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: AppType.family,
      bodyColor: AppColors.darkInk,
      displayColor: AppColors.darkInk,
    ),
  );
}

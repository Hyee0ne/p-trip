import 'package:flutter/material.dart';
import '../../data/models/models.dart';

/// 스팟 사진 자리.
///
/// M1 전까지는 유형색 그라데이션으로 그린다. 사진이 없다고 화면을 숨기지 않는다
/// (SCREENS.md CO-03: "사진 없다고 화면을 숨기지 않는다").
/// M1 이후 [imageUrl]이 들어오면 이 위젯이 실제 이미지로 대체한다.
class SpotImage extends StatelessWidget {
  const SpotImage({
    super.key,
    required this.type,
    this.spotId,
    this.width,
    this.height,
    this.radius = 14,
    this.imageUrl,
  });

  final SpotType type;

  /// 있으면 `assets/images/<spotId>.jpg`를 먼저 찾는다.
  final String? spotId;

  final double? width;
  final double? height;
  final double radius;

  /// M1 이후 TourAPI 사진 URL이 들어온다.
  final String? imageUrl;

  /// 유형별 색. 사진이 들어오기 전까지 이 그라데이션이 자리를 지킨다.
  /// 3스톱 선형 + 밝은 광원 + 가장자리 비네팅을 겹쳐 사진처럼 깊이를 만든다.
  static const _palettes = <SpotType, List<Color>>{
    SpotType.market: [Color(0xFFFFE3B0), Color(0xFFF0A85E), Color(0xFFB85C33)],
    SpotType.view: [Color(0xFFCFE6F2), Color(0xFFFCA97E), Color(0xFFD4604F)],
    SpotType.food: [Color(0xFFF9EACA), Color(0xFFE0C08A), Color(0xFF9C7245)],
    SpotType.culture: [Color(0xFFE8F3FA), Color(0xFFA9D4E6), Color(0xFF5A8FB5)],
    SpotType.stay: [Color(0xFFE6DEF3), Color(0xFFB4A2D2), Color(0xFF6E5595)],
    SpotType.camp: [Color(0xFFDFF0D6), Color(0xFF8FBF96), Color(0xFF44725A)],
    SpotType.attraction: [Color(0xFFDEF4FB), Color(0xFF7FCCE8), Color(0xFF2E7BA8)],
  };

  /// 광원 위치도 유형마다 달라야 같은 그림으로 안 보인다.
  static const _lightAt = <SpotType, Alignment>{
    SpotType.market: Alignment(-0.5, -0.6),
    SpotType.view: Alignment(0.1, 0.35),
    SpotType.food: Alignment(-0.45, -0.35),
    SpotType.culture: Alignment(0.4, -0.55),
    SpotType.stay: Alignment(-0.2, -0.5),
    SpotType.camp: Alignment(0.35, -0.5),
    SpotType.attraction: Alignment(0.0, -0.7),
  };

  @override
  Widget build(BuildContext context) {
    final c = _palettes[type] ?? _palettes[SpotType.attraction]!;
    final light = _lightAt[type] ?? Alignment.topLeft;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 바탕 — 사진을 못 찾을 때 그대로 남아 자리를 지킨다
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: c,
                  stops: const [0, 0.52, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: light,
                  radius: 0.85,
                  colors: const [Color(0x8CFFFFFF), Color(0x1AFFFFFF), Color(0x00FFFFFF)],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
            // 사진 — 없으면 조용히 그라데이션만 남는다
            if (spotId != null)
              Image.asset(
                'assets/images/$spotId.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            // 비네팅 — 가장자리를 눌러 깊이를 만든다
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.95,
                  colors: [Color(0x00000000), Color(0x00000000), Color(0x2E000000)],
                  stops: [0, 0.62, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

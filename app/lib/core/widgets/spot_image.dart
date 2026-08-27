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
    this.width,
    this.height,
    this.radius = 14,
    this.imageUrl,
  });

  final SpotType type;
  final double? width;
  final double? height;
  final double radius;
  final String? imageUrl;

  static const _palettes = <SpotType, List<Color>>{
    SpotType.market: [Color(0xFFFBD79B), Color(0xFFF0A85E), Color(0xFFDB7C4A)],
    SpotType.view: [Color(0xFFCFE6F2), Color(0xFFFCA97E), Color(0xFFF2846C)],
    SpotType.food: [Color(0xFFF5E2BC), Color(0xFFE0C08A), Color(0xFFC79E68)],
    SpotType.culture: [Color(0xFFDDEFF6), Color(0xFFA9D4E6), Color(0xFF7FB6D2)],
    SpotType.stay: [Color(0xFFDCD3EC), Color(0xFFB4A2D2), Color(0xFF8A72B8)],
    SpotType.camp: [Color(0xFFCBE4C4), Color(0xFF8FBF96), Color(0xFF5E9270)],
    SpotType.attraction: [Color(0xFFC7E9F5), Color(0xFF7FCCE8), Color(0xFF46A8D4)],
  };

  @override
  Widget build(BuildContext context) {
    final c = _palettes[type] ?? _palettes[SpotType.attraction]!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: c,
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.4, -0.5),
                radius: 0.9,
                colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

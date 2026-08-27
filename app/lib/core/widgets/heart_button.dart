import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../saves.dart';
import '../strings.dart';
import '../theme.dart';
import 'app_toast.dart';

/// 하트(찜) — 토글. on 시 토스트 "찜에 담았어요" (SCREENS.md §0.2).
///
/// 상태를 프롭으로 내려받지 않고 [savesProvider]를 직접 본다.
/// 같은 스팟의 하트가 화면 여러 곳에 있어도 항상 같은 상태를 보여준다.
class HeartButton extends ConsumerWidget {
  const HeartButton({super.key, required this.spotId, this.size = 15, this.color, this.onColor});

  final String spotId;
  final double size;
  final Color? color;
  final Color? onColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(savesProvider).isLiked(spotId);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final added = ref.read(savesProvider.notifier).toggleLike(spotId);
        if (added) showAppToast(context, S.toastSaved);
      },
      child: Padding(
        // 아이콘이 작아도 터치 영역은 44pt 이상 (§0.2 접근성)
        padding: EdgeInsets.all((44 - size) / 2),
        child: Icon(
          liked ? Icons.favorite : Icons.favorite_border,
          size: size,
          color: liked ? (onColor ?? AppColors.marketRed) : (color ?? AppColors.ink3),
        ),
      ),
    );
  }
}

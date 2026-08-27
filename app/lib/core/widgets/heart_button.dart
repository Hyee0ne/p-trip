import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../saves.dart';
import '../strings.dart';
import '../theme.dart';
import 'app_toast.dart';

/// 하트(찜) — 토글. on 시 토스트 "찜에 담았어요" (SCREENS.md §0.2).
///
/// ⚠ **터치 영역과 보이는 크기를 한 위젯이 같이 소유한다.**
///   예전엔 버튼이 스스로 44pt 패딩을 넣고 호출부가 그걸 30pt 원에 넣어서
///   아이콘이 중앙에서 밀려났다. 크기 규칙을 두 곳에 나눠 쓰면 반드시 충돌한다.
class HeartButton extends ConsumerWidget {
  const HeartButton({
    super.key,
    required this.spotId,
    this.iconSize = 15,
    this.tapSize = 44,
    this.chipSize,
    this.color,
    this.onColor,
    this.onToggle,
  });

  final String spotId;

  /// 아이콘 자체 크기.
  final double iconSize;

  /// 투명 터치 영역. 레이아웃을 차지하는 크기이기도 하다. 44pt 이상.
  final double tapSize;

  /// 값을 주면 아이콘 뒤에 흰 원을 그린다 (사진 위에 얹을 때).
  final double? chipSize;

  final Color? color;
  final Color? onColor;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(savesProvider).isLiked(spotId);
    final icon = Icon(
      liked ? Icons.favorite : Icons.favorite_border,
      size: iconSize,
      color: liked ? (onColor ?? AppColors.marketRed) : (color ?? AppColors.ink3),
    );

    return Semantics(
      button: true,
      selected: liked,
      label: liked ? '찜 해제' : S.toastSaved,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final added = ref.read(savesProvider.notifier).toggleLike(spotId);
          if (added) showAppToast(context, S.toastSaved);
          onToggle?.call();
        },
        child: SizedBox(
          width: tapSize,
          height: tapSize,
          child: Center(
            child: chipSize == null
                ? icon
                : Container(
                    width: chipSize,
                    height: chipSize,
                    decoration: const BoxDecoration(
                      color: Color(0xF0FFFFFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x1F1E4650), blurRadius: 6, offset: Offset(0, 1)),
                      ],
                    ),
                    child: Center(child: icon),
                  ),
          ),
        ),
      ),
    );
  }
}

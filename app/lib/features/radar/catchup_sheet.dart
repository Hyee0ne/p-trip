import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/base_camp.dart';
import '../../core/saves.dart';
import '../../core/trip_log.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/spot_image.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/models.dart';
import '../handoff/handoff_sheet.dart';

/// DR-03 몰아보기 — 정차했을 때 아까 스쳐간 곳들을 한 번에 보여준다.
///
/// ⚠ **"되돌아가기" 유도 문구를 쓰지 않는다** (SCREENS.md DR-03).
///   갈지 말지는 사용자가 정한다. 우리는 목록만 낸다 — 재촉 금지 원칙이 여기서도 같다.
class CatchupSheet extends ConsumerStatefulWidget {
  const CatchupSheet({super.key, required this.passed, required this.onDone});

  /// 스쳐간 발견. 2~4개일 때만 띄운다.
  final List<Discovery> passed;

  /// 시트를 닫을 때 — 처리하고 남은 목록을 돌려준다.
  final void Function(List<Discovery> remaining) onDone;

  static Future<void> show(
    BuildContext context, {
    required List<Discovery> passed,
    required void Function(List<Discovery> remaining) onDone,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CatchupSheet(passed: passed, onDone: onDone),
    );
  }

  @override
  ConsumerState<CatchupSheet> createState() => _CatchupSheetState();
}

class _CatchupSheetState extends ConsumerState<CatchupSheet> {
  late final List<Discovery> _items = [...widget.passed];

  void _remove(Discovery d) {
    setState(() => _items.remove(d));
    if (_items.isEmpty && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    widget.onDone(_items);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkLine,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.x5),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: Text(
              S.catchupTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.darkInk,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.x4),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x3),
              itemBuilder: (_, i) => _card(_items[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Discovery d) {
    final spot = d.spot;
    return SizedBox(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpotImage(
            type: spot.type,
            spotId: spot.id,
            imageUrl: spot.imageUrl,
            width: 250,
            height: 108,
            radius: 14,
          ),
          const SizedBox(height: AppSpace.x2),
          Text(
            spot.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.darkInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            spot.blurb,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.darkInk2),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppTouch.min,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.routeBlue,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    onPressed: () {
                      // 거점을 지킨 채 들른다 — 발견은 경유지로 간다.
                      final p = HandoffSheet.visitParams(
                        spot: HandoffPlace(spot.name, spot.lat, spot.lng),
                        base: ref.read(baseCampProvider),
                        driving: ref.read(tripLogProvider).active != null,
                      );
                      HandoffSheet.show(
                        context,
                        mode: HandoffMode.visit,
                        destination: p.destination,
                        via: p.via,
                      );
                      _remove(d);
                    },
                    child: const Text(
                      S.catchupGo,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _icon(Icons.favorite_border, S.catchupKeep, () {
                ref.read(savesProvider.notifier).toggleLike(SaveRef.spot(spot.id));
                ref.read(savesProvider.notifier).clearPassed(spot.id);
                showAppToast(context, S.toastSaved);
                _remove(d);
              }),
              const SizedBox(width: 6),
              // 지우기 = 이 목록에서만 뺀다. 스쳐간 기록 자체는 남는다 (여행기에 쓰인다).
              _icon(Icons.close, S.catchupDrop, () => _remove(d)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _icon(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
    message: tooltip,
    child: SizedBox(
      width: AppTouch.min,
      height: AppTouch.min,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.darkLine),
          foregroundColor: AppColors.darkInk2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
        onPressed: onTap,
        child: Icon(icon, size: 18),
      ),
    ),
  );
}

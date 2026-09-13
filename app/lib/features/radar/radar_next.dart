import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/spot_image.dart';
import '../../data/models/models.dart';

/// DR-07 「여기서 앞쪽으로」 — 들른 뒤 다음 후보 (SCREENS.md DR-07, 2026-09-13).
///
/// 「들르기」로 티맵이 그 스팟까지 데려다주면 거기서 안내가 끝난다. 밥을 먹고 나오면 다음이 없었다.
/// 목적지를 대신 정하지 않는다 — 앞쪽 후보를 **최대 3곳** 보여주고, 고르면 티맵이 안내한다.
/// 고르지 않으면 「그냥 N번 국도로 돌아가기」 하나면 된다. 재촉 문구는 없다 (원칙 6).

/// 큐에서 이미 알렸거나 들른 곳을 빼고, DR-02 와 같은 점수로 위에서 [max]곳.
/// 점수가 같으면 큐 순서(가까운 순)를 지킨다.
List<Discovery> pickNextAhead(
  List<Discovery> queue,
  Set<String> exclude,
  double Function(Spot) score, {
  int max = 3,
}) {
  final rest = [
    for (final d in queue)
      if (!exclude.contains(d.spot.id)) d,
  ];
  final indexed = rest.asMap().entries.toList()
    ..sort((a, b) {
      final s = score(b.value.spot).compareTo(score(a.value.spot));
      return s != 0 ? s : a.key.compareTo(b.key);
    });
  return [for (final e in indexed.take(max)) e.value];
}

class NextAhead extends StatelessWidget {
  const NextAhead({
    super.key,
    required this.routeId,
    required this.items,
    required this.loading,
    required this.kmOf,
    required this.onVisit,
    required this.onOpen,
    required this.onBackToRoute,
  });

  final int routeId;
  final List<Discovery> items;
  final bool loading;

  /// 카드가 뜬 순간처럼 기기 안에서 잰 직선거리. 좌표를 모르면 null — 숫자를 지어내지 않는다.
  final double? Function(Spot) kmOf;
  final void Function(Discovery) onVisit;
  final void Function(Discovery) onOpen;
  final VoidCallback onBackToRoute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                S.nextTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkInk,
                ),
              ),
              const Spacer(),
              if (!loading)
                Text(
                  S.nextSub(items.length),
                  style: const TextStyle(fontSize: 11, color: AppColors.darkInk3),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.darkLine),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkInk3),
                      ),
                    ),
                  )
                : items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Text(
                      S.nextEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.darkInk2),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        _NextRow(
                          d: items[i],
                          km: kmOf(items[i].spot),
                          onVisit: () => onVisit(items[i]),
                          onOpen: () => onOpen(items[i]),
                        ),
                        if (i != items.length - 1)
                          const Divider(height: 1, thickness: 1, color: AppColors.darkLine),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: onBackToRoute,
              style: TextButton.styleFrom(minimumSize: const Size(0, AppTouch.min)),
              child: Text(
                S.nextBackToRoute(routeId),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.darkInk2,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.darkInk3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextRow extends StatelessWidget {
  const _NextRow({required this.d, required this.km, required this.onVisit, required this.onOpen});
  final Discovery d;
  final double? km;
  final VoidCallback onVisit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = d.spot;
    // 시의성이 있으면 앞에, 거리는 있을 때만 — 없는 숫자를 지어내지 않는다.
    final meta = [
      if (s.timelinessNote.isNotEmpty) s.timelinessNote,
      if (km != null) S.cardFromHere(km!),
    ].join(' · ');
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Row(
          children: [
            SpotImage(
              type: s.type,
              spotId: s.id,
              imageUrl: s.imageUrl,
              width: 42,
              height: 42,
              radius: 10,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkInk,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: s.timelinessNote.isNotEmpty ? AppColors.sun : AppColors.darkInk2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 핸드오프로 간다 — 카드의 「들르기」와 같은 말, 같은 곳으로.
            SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: onVisit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                child: const Text(S.cardVisit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';

/// 데이터 출처 (SCREENS.md MY-01/03 설정).
///
/// ⚠ **이 화면은 장식이 아니라 의무다.** 공공누리는 유형과 무관하게 출처표시를
///   요구하고, 스토어 설명이 아니라 **콘텐츠를 쓰는 앱 안에서** 밝혀야 한다.
///   관광공사 사진·개요를 그대로 띄우는 앱이라 더 그렇다.
/// ⚠ 목록은 `S.sources` 하나만 본다. 파이프라인이 안 부르는 출처를 여기 적지 않는다.
class DataSourcesSheet extends StatelessWidget {
  const DataSourcesSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    // ⚠ 기본 높이(화면의 9/16)로는 넘친다. 글자 크기를 키운 기기에선 더 넘친다.
    isScrollControlled: true,
    builder: (_) => const DataSourcesSheet(),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      // 출처는 지울 수 없는 목록이라 화면이 작으면 스크롤로 감당한다.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 12, AppSpace.gutter, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.x5),
            const Text(S.sourcesRow, style: AppType.h2),
            const SizedBox(height: AppSpace.x2),
            const Text(
              S.sourcesIntro,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.ink2),
            ),
            const SizedBox(height: AppSpace.x5),
            for (final s in S.sources) _Row(org: s.org, what: s.what),
            const Divider(height: AppSpace.x6, thickness: 1, color: AppColors.line),
            const _Row(org: S.sourcesMapOrg, what: S.sourcesMapRow),
            const _Row(org: S.sourcesNavOrg, what: S.sourcesNavRow),
            const SizedBox(height: AppSpace.x5),
            const Text(
              S.sourcesNote,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.org, required this.what});

  final String org;
  final String what;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.x4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          org,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 2),
        Text(what, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.ink2)),
      ],
    ),
  );
}

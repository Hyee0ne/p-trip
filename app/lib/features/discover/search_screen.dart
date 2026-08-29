import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/chips.dart';
import '../../data/repositories/providers.dart';

/// SR 검색 (SCREENS.md §SR) — 모달. 탭바를 덮는다.
///
/// ⚠ 훑어보기와 **반드시 구분되어야 한다.** 구분 신호 3개:
///   1. 배경이 흰색 (훑어보기는 연한 틴트)
///   2. 결과는 리스트 행 (훑어보기는 2열 그리드)
///   3. 헤더에 토글이 없다 — ← 와 입력창뿐
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  bool _today = false;
  bool _near = false;

  /// 최근 검색. **비어서 시작한다** — 한 번도 검색한 적 없는 사람에게
  /// 검색 기록을 보여주고 있었다. 없는 걸 지어내지 않는다.
  final _recent = <String>[];
  static const _kRecent = 'search.recent.v1';
  static const _maxRecent = 8;

  static const _suggestions = ['오늘 장날', '물회', '등대', '캠핑장', '해수욕장', '전통시장'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    unawaited(_restoreRecent());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String q) {
    setState(() {
      _query = q;
      _controller.text = q;
      _recent.remove(q);
      if (q.isNotEmpty) _recent.insert(0, q);
      if (_recent.length > _maxRecent) _recent.removeRange(_maxRecent, _recent.length);
    });
    _focus.unfocus();
    unawaited(_save());
  }

  Future<void> _restoreRecent() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getStringList(_kRecent);
      if (saved == null || !mounted || _recent.isNotEmpty) return;
      setState(() => _recent.addAll(saved));
    } catch (_) {
      // 저장소를 못 열어도 검색은 된다. 이번 실행에만 기록이 없다.
    }
  }

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(_kRecent, _recent);
    } catch (_) {
      /* 무시 */
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.trim().isNotEmpty;
    return Scaffold(
      // 신호 1 — 흰 배경
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            // 검색어가 있을 때만 필터를 보여준다 — 입력 전 화면을 조용히 유지
            if (hasQuery) _filters(),
            Expanded(child: hasQuery ? _results() : _beforeInput()),
          ],
        ),
      ),
    );
  }

  // 신호 3 — 토글 없음. ← 와 입력창뿐.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: AppColors.ink3),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _submit,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: S.searchHint,
                        hintStyle: TextStyle(
                          fontSize: 14.5,
                          color: AppColors.ink3,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() {
                        _controller.clear();
                        _query = '';
                      }),
                      child: const Icon(Icons.close, size: 16, color: AppColors.ink3),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 검색어와 조건을 함께 쓰는 게 실제 사용 방식이라 결과 화면에도 필터를 남긴다 (§SR).
  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 11, AppSpace.gutter, 0),
      child: Row(
        children: [
          DiscoverFilterChip(
            label: S.filterToday,
            selected: _today,
            onTap: () => setState(() => _today = !_today),
          ),
          const SizedBox(width: 7),
          DiscoverFilterChip(
            label: S.filterNear,
            selected: _near,
            onTap: () => setState(() => _near = !_near),
          ),
          const Spacer(),
          const FilterMoreChip(),
        ],
      ),
    );
  }

  Widget _beforeInput() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x5, AppSpace.gutter, 16),
      children: [
        // 최근 검색 없으면 섹션 자체를 그리지 않는다 (§SR)
        if (_recent.isNotEmpty) ...[
          Row(
            children: [
              const SectionLabel(S.searchRecent),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(_recent.clear);
                  unawaited(_save());
                },
                child: const Text(
                  S.searchClear,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.ink3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.x2),
          for (var i = 0; i < _recent.length; i++) ...[
            InkWell(
              onTap: () => _submit(_recent[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 15, color: AppColors.ink3),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _recent[i],
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _recent.removeAt(i));
                        unawaited(_save());
                      },
                      child: const Icon(Icons.close, size: 15, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
            ),
            if (i != _recent.length - 1)
              const Divider(height: 1, thickness: 1, color: AppColors.line),
          ],
          const SizedBox(height: AppSpace.x6),
        ],
        const SectionLabel(S.searchSuggest),
        const SizedBox(height: AppSpace.x3),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final s in _suggestions)
              DiscoverFilterChip(label: s, selected: false, onTap: () => _submit(s)),
          ],
        ),
      ],
    );
  }

  // 신호 2 — 그리드가 아니라 리스트
  Widget _results() {
    final async = ref.watch(searchProvider((query: _query.trim(), today: _today, near: _near)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const Center(child: Text(S.errNetwork)),
      data: (spots) {
        if (spots.isEmpty) return _noResult();
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x5, AppSpace.gutter, 16),
          children: [
            SectionLabel('${spots.length}곳'),
            const SizedBox(height: AppSpace.x2),
            for (var i = 0; i < spots.length; i++) ...[
              SpotListRow(spot: spots[i], onTap: () => context.push('/spot/${spots[i].id}')),
              if (i != spots.length - 1)
                const Divider(height: 1, thickness: 1, color: AppColors.line),
            ],
          ],
        );
      },
    );
  }

  /// 결과 0건 — ⚠ 유사 결과를 억지로 채우지 않는다 (§SR).
  Widget _noResult() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x8, AppSpace.gutter, 16),
      children: [
        Text(
          S.searchEmpty(_query.trim()),
          textAlign: TextAlign.center,
          style: AppType.body.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: AppSpace.x8),
        const SectionLabel(S.searchSuggest),
        const SizedBox(height: AppSpace.x3),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final s in _suggestions)
              DiscoverFilterChip(label: s, selected: false, onTap: () => _submit(s)),
          ],
        ),
      ],
    );
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **정확한 GPS 좌표는 기기를 떠나지 않는다** (2026-09-07).
///
/// 위치정보 문의 답변(docs/위치정보_문의.md)이 "사업자가 보유한 다른 정보와 결합해
/// 특정 개인을 식별할 수 있는지"를 기준으로 든다. 우리는 식별자를 함께 보내지 않고
/// 저장도 하지 않지만(함수가 전부 `STABLE`), **보내는 값 자체를 뭉개는 것**이
/// 우리가 쥔 유일한 손잡이다 — 인프라 로그 설정은 우리가 못 바꾼다.
///
/// ⚠ 이 테스트는 **소스를 읽는다.** 새 쿼리를 추가하면서 `_cell()` 을 빼먹는 게
///   이 방어가 무너지는 유일한 경로라서다. 화면도 린트도 그걸 못 잡는다.
void main() {
  final src = File('lib/data/repositories/supabase_discover_repository.dart').readAsStringSync();

  test('서버로 나가는 좌표는 전부 격자를 거친다', () {
    // `'p_lat': ...` 꼴로 서버에 실려 나가는 자리. 값이 `_cell(` 로 시작해야 한다.
    final outgoing = RegExp(r"'(p_lat|p_lng|lat|lng)'\s*:\s*\??([A-Za-z_][A-Za-z0-9_]*)");
    final bad = <String>[];
    for (final m in outgoing.allMatches(src)) {
      final value = m.group(2)!;
      if (value != '_cell' && value != '_cellOrNull') bad.add(m.group(0)!);
    }
    expect(bad, isEmpty, reason: '격자를 안 거치고 나가는 좌표가 있다: $bad');
  });

  test('길찾기로 나가는 좌표쌍도 격자를 거친다', () {
    // compare_routes 는 `'from': [lat, lng]` 꼴이라 위 정규식에 안 걸린다.
    for (final key in ["'from'", "'to'"]) {
      final m = RegExp('$key: \\[([^\\]]*)\\]').firstMatch(src);
      expect(m, isNotNull, reason: '$key 를 못 찾았다 — 테스트가 낡았다');
      expect(
        m!.group(1)!.split(',').every((v) => v.trim().startsWith('_cell(')),
        isTrue,
        reason: '$key 의 좌표가 격자를 안 거친다: ${m.group(0)}',
      );
    }
  });

  test('격자는 0.01도다 — 위도 약 1.1km', () {
    expect(
      src,
      contains('static double _cell(double v) => (v * 100).roundToDouble() / 100;'),
      reason: '격자 크기를 바꿨다면 왜 바꿨는지 문서(위치정보_문의.md)에 남길 것',
    );
  });

  test('좌표는 URL 이 아니라 요청 본문으로만 나간다', () {
    // ⚠ 게이트웨이 로그는 URL 은 통째로 남기고 **본문은 안 남긴다** (2026-09-07 확인).
    //   좌표를 쿼리스트링에 실으면 그 순간 액세스 로그에 좌표가 남는다.
    expect(
      RegExp(r"\?[^'\n]*\b(lat|lng)=").hasMatch(src),
      isFalse,
      reason: '좌표가 URL 쿼리스트링에 실렸다 — 게이트웨이 로그에 그대로 남는다',
    );
  });
}

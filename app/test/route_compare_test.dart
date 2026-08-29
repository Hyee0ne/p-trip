import 'package:flutter_test/flutter_test.dart';
import 'package:p_trip/data/models/models.dart';

/// §3.7 소요시간 표기. **비교 근거일 뿐 ETA가 아니다.**
void main() {
  test('한 시간 미만은 분만', () {
    expect(RouteCompare.label(44), '44분');
    expect(RouteCompare.label(59), '59분');
  });

  test('정각은 시간만', () {
    expect(RouteCompare.label(120), '2시간');
  });

  test('시간과 분', () {
    expect(RouteCompare.label(62), '1시간 2분');
    expect(RouteCompare.label(230), '3시간 50분');
  });

  test('국도가 더 걸리는 만큼이 설득의 값이다', () {
    const c = RouteCompare(highwayMin: 44, routeMin: 62);
    expect(c.extraMin, 18);
  });
}

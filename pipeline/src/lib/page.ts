/**
 * PostgREST 는 **서버가 1,000행에서 끊는다.** `.limit(5000)` 도 `.range(0,4999)` 도 못 넘는다.
 *
 * ⚠ 그냥 select 하면 조용히 1,000행만 온다. 에러도 경고도 없다.
 *   2026-09-06: `fetch:spots` 의 '이미 받은 목록'이 이렇게 잘려서, 2,042건 중 1,000건만
 *   인식하고 **나머지를 매일 밤 다시 받았다.** 이틀치 2,000콜이 그렇게 날아갔고
 *   로그에는 '1000건 적재'로 찍혀 멀쩡해 보였다.
 *
 * 쓰는 법:
 *   const rows = await pageAll((from, to) =>
 *     db.from('spots').select('id, name').gt('trust_score', 0).range(from, to));
 */
export async function pageAll<T>(
  query: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: { message: string } | null }>,
  step = 1000,
): Promise<T[]> {
  const out: T[] = [];
  for (let from = 0; ; from += step) {
    const { data, error } = await query(from, from + step - 1);
    if (error) throw new Error(error.message);
    if (!data?.length) break;
    out.push(...data);
    if (data.length < step) break;
  }
  return out;
}

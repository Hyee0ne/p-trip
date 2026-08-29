/**
 * 개요(overview) 채우기 — **게이트를 통과한 스팟만**.
 *
 * detailCommon2(공통정보조회)는 일일 요청 제한이 빠듯하다. 그런데 목록 응답에
 * 사진·주소·전화가 이미 들어 있어서, 이 API는 사실상 **개요 하나** 때문에 부른다.
 * 개요는 게이트 10점이라 통과 여부를 거의 안 가른다 — 대신 CO-03 상세 화면에서
 * 사람이 읽는 글이라, **실제로 화면에 뜰 스팟**에만 채우면 충분하다.
 *
 * 그래서 순서를 뒤집었다: 먼저 게이트를 매기고, 통과한 것만 개요를 받는다.
 * 하루에 못 끝내도 이어받는다 (이미 채운 건 건너뛴다).
 *
 * 실행: cd pipeline && npm run fetch:overview
 *       LIMIT=300 npm run fetch:overview   # 오늘 이만큼만
 */

import { supabase } from './lib/supabase.js';

const KEY = process.env.TOURAPI_KEY?.trim();
const BASE = 'https://apis.data.go.kr/B551011/KorService2';
const COMMON = 'MobileOS=ETC&MobileApp=PTrip&_type=json';

/** 하루 한도에 닿기 전에 멈추고 싶을 때. */
const LIMIT = Number(process.env.LIMIT ?? 100000);

/** 게이트 임계. 이 아래는 상세 화면에서도 뒤로 밀리니 개요를 급히 받을 이유가 없다. */
const GATE = 60;

let quotaHit = false;

async function overviewOf(contentId: string): Promise<string | null> {
  const url = `${BASE}/detailCommon2?serviceKey=${KEY}&${COMMON}&contentId=${contentId}`;
  for (let n = 1; n <= 3; n++) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(15_000) });
      const text = await res.text();
      if (/LIMITED_NUMBER/i.test(text)) {
        quotaHit = true;
        return null;
      }
      const item = JSON.parse(text)?.response?.body?.items?.item;
      const o = (Array.isArray(item) ? item[0] : item)?.overview as string | undefined;
      if (!o) return null;
      const t = o.replace(/<[^>]+>/g, ' ').replace(/&[a-z]+;/g, ' ').replace(/\s+/g, ' ').trim();
      return t || null;
    } catch {
      if (n === 3) return null;
      await new Promise((r) => setTimeout(r, 400 * n));
    }
  }
  return null;
}

async function main() {
  if (!KEY) throw new Error('TOURAPI_KEY가 비어 있습니다.');
  const db = supabase();

  const { data, error } = await db
    .from('spots')
    .select('id, tourapi_contentid, name, trust_score')
    .gte('trust_score', GATE)
    .is('overview', null)
    .not('tourapi_contentid', 'is', null)
    .order('trust_score', { ascending: false })
    .limit(LIMIT);
  if (error) throw new Error(`대상 조회 실패: ${error.message}`);

  const targets = data ?? [];
  if (!targets.length) {
    console.log('· 개요를 채울 스팟이 없습니다 (게이트 통과분은 이미 다 채웠습니다).');
    return;
  }
  console.log(`게이트 ${GATE} 통과 + 개요 없음: ${targets.length}건`);

  let filled = 0;
  let empty = 0;
  const LANES = 6;

  for (let i = 0; i < targets.length && !quotaHit; i += LANES) {
    const batch = targets.slice(i, i + LANES);
    const results = await Promise.all(
      batch.map(async (t) => ({ id: t.id, overview: await overviewOf(t.tourapi_contentid!) })),
    );
    const rows = results.filter((r) => r.overview);
    if (rows.length) {
      // 개요만 갱신한다. 다른 컬럼을 건드리지 않는다.
      await Promise.all(
        rows.map((r) => db.from('spots').update({ overview: r.overview }).eq('id', r.id)),
      );
      filled += rows.length;
    }
    empty += results.length - rows.length;
    if ((i + LANES) % 60 === 0) console.log(`  ${Math.min(i + LANES, targets.length)}/${targets.length}`);
  }

  console.log(`\n✓ 개요 ${filled}건 채움 · 원본에 개요가 없는 스팟 ${empty}건`);
  if (quotaHit) {
    console.log('⚠ 일일 요청 제한에 닿아 멈췄습니다. 내일 다시 돌리면 남은 것부터 이어받습니다.');
  }
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

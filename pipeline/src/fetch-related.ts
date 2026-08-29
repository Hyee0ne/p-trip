/**
 * 연관 관광지 → spot_links (발자국 데이터).
 *
 * TourAPI `TarRlteTarService1`. **`baseYm`으로 시점을 고를 수 있다**(2026-08-29 실측) —
 * 두 달을 각각 받아 비교하면 데이터랩 없이도 "요즘 차들이 몰래 가는 곳"을 만들 수 있다.
 *
 * ⚠ `rlteRank`는 그 달의 순위일 뿐이다. **절대순위로 정렬하지 않는다** (원칙 3).
 *   쓰는 건 순위 자체가 아니라 **두 시점 사이의 변화**다.
 * ⚠ 이 API는 좌표를 안 준다. 이름으로만 우리 스팟에 붙일 수 있다.
 *   시장에서 헐거운 이름 매칭에 데였으므로 여기서는 **정규화 후 정확 일치**만 인정한다.
 *
 * 실행: cd pipeline && npm run fetch:related
 *       BASE_YM=202606,202603 npm run fetch:related
 */

import { supabase } from './lib/supabase.js';

const KEY = process.env.TOURAPI_KEY?.trim();
const URL = 'https://apis.data.go.kr/B551011/TarRlteTarService1/areaBasedList1';
const COMMON = 'MobileOS=ETC&MobileApp=PTrip&_type=json';

/** 강원특별자치도(51) · 데모 구간 시군구. signguCd는 5자리 법정동 코드다. */
const SIGUNGU = [
  { name: '삼척시', areaCd: '51', signguCd: '51230' },
  { name: '동해시', areaCd: '51', signguCd: '51170' },
  { name: '강릉시', areaCd: '51', signguCd: '51150' },
];

type Row = {
  baseYm: string;
  tAtsNm: string;
  rlteTatsNm: string;
  rlteCtgryLclsNm?: string;
  rlteCtgryMclsNm?: string;
  rlteRank?: string;
};

/** 이름을 맞춰보기 위한 정규화. 괄호 주석·공백·중점만 걷어낸다 — 그 이상은 안 건드린다. */
function norm(s: string): string {
  return s.replace(/\(.*?\)/g, '').replace(/[\s·・]/g, '').trim();
}

async function page(areaCd: string, signguCd: string, baseYm: string, pageNo: number): Promise<Row[]> {
  const url = `${URL}?serviceKey=${KEY}&${COMMON}&numOfRows=100&pageNo=${pageNo}&baseYm=${baseYm}&areaCd=${areaCd}&signguCd=${signguCd}`;
  const res = await fetch(url, { signal: AbortSignal.timeout(20_000) });
  const text = await res.text();
  if (/LIMITED_NUMBER/i.test(text)) throw new Error('일일 요청 제한 초과');
  try {
    const it = JSON.parse(text)?.response?.body?.items?.item;
    if (!it) return [];
    return Array.isArray(it) ? it : [it];
  } catch {
    return [];
  }
}

async function collect(baseYm: string): Promise<Row[]> {
  const out: Row[] = [];
  for (const sg of SIGUNGU) {
    let n = 0;
    for (let p = 1; p <= 30; p++) {
      const rows = await page(sg.areaCd, sg.signguCd, baseYm, p);
      out.push(...rows);
      n += rows.length;
      if (rows.length < 100) break;
    }
    console.log(`    ${sg.name} ${n}건`);
  }
  return out;
}

async function main() {
  if (!KEY) throw new Error('TOURAPI_KEY가 비어 있습니다.');
  const db = supabase();

  // 기본은 최근 확보된 달과 그 3개월 전. 변화를 보려면 시점이 둘 필요하다.
  const months = (process.env.BASE_YM ?? '202606,202603').split(',').map((s) => s.trim());

  const { data: spotRows, error } = await db.from('spots').select('id, name').limit(5000);
  if (error) throw new Error(`스팟 조회 실패: ${error.message}`);
  const byName = new Map<string, string>();
  for (const s of spotRows ?? []) byName.set(norm(s.name as string), s.id as string);
  console.log(`스팟 ${spotRows?.length ?? 0}건으로 이름 색인`);

  const links: Record<string, unknown>[] = [];
  const rankByMonth = new Map<string, Map<string, number>>(); // baseYm → 'from|to' → rank

  for (const ym of months) {
    console.log(`\n${ym}:`);
    const rows = await collect(ym);
    const ranks = new Map<string, number>();
    let hit = 0;
    for (const r of rows) {
      const from = byName.get(norm(r.tAtsNm ?? ''));
      const to = byName.get(norm(r.rlteTatsNm ?? ''));
      if (!from || !to || from === to) continue;
      hit++;
      const rank = Number(r.rlteRank);
      ranks.set(`${from}|${to}`, Number.isFinite(rank) ? rank : 0);
      links.push({
        from_spot_id: from,
        to_spot_id: to,
        category: [r.rlteCtgryLclsNm, r.rlteCtgryMclsNm].filter(Boolean).join(' > ') || null,
        rank: Number.isFinite(rank) ? rank : null,
        base_ym: ym,
      });
    }
    rankByMonth.set(ym, ranks);
    console.log(`    → 우리 스팟끼리 이어진 링크 ${hit}건 (전체 ${rows.length}건 중)`);
  }

  if (!links.length) {
    console.log('\n· 붙일 링크가 없습니다. 스팟 수집이 더 채워져야 합니다.');
    return;
  }
  const { error: e2 } = await db
    .from('spot_links')
    .upsert(links, { onConflict: 'from_spot_id,to_spot_id,base_ym' });
  if (e2) throw new Error(`spot_links 적재 실패: ${e2.message}`);
  console.log(`\n✓ spot_links ${links.length}건 적재`);

  // 두 시점이 다 있으면 변화를 본다. ⚠ 순위 자체가 아니라 **오른 폭**만 본다.
  const [recent, older] = months;
  const a = rankByMonth.get(recent);
  const b = rankByMonth.get(older);
  if (!a || !b || !b.size) {
    console.log('· 시점이 하나뿐이라 변화는 아직 못 낸다.');
    return;
  }
  const risen: { key: string; from: number; to: number }[] = [];
  for (const [key, now] of a) {
    const then = b.get(key);
    if (then === undefined) continue;
    if (now < then) risen.push({ key, from: then, to: now }); // 숫자가 작을수록 상위
  }
  risen.sort((x, y) => y.from - y.to - (x.from - x.to));
  const nameById = new Map((spotRows ?? []).map((s) => [s.id as string, s.name as string]));
  console.log(`\n순위가 오른 연결 ${risen.length}건 — 상위 8건:`);
  for (const r of risen.slice(0, 8)) {
    const [f, t] = r.key.split('|');
    console.log(`  ${nameById.get(f)} → ${nameById.get(t)}  ${r.from}위 → ${r.to}위`);
  }
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

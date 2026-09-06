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

import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { pageAll } from './lib/page.js';
import { supabase } from './lib/supabase.js';

const KEY = process.env.TOURAPI_KEY?.trim();
const URL = 'https://apis.data.go.kr/B551011/TarRlteTarService1/areaBasedList1';
const COMMON = 'MobileOS=ETC&MobileApp=PTrip&_type=json';

/**
 * 시군구 목록. **`ldongCode2` 가 정본을 준다** — 손으로 적지 않는다.
 *
 * ⚠ 전에는 삼척·동해·강릉 셋만 박혀 있었다. 스팟이 서울로 들어와도
 *   연관관광지는 강원만 봤다 (2026-09-04). `fetch:spots` 가 시도 코드에서
 *   같은 실수를 했던 것과 같은 종류다.
 * ⚠ `signguCd` 는 **시도(2자리) + 시군구(3자리)** 다. ldongCode2 는 뒤 3자리만 준다.
 *
 * 순서는 `fetch:spots` 와 같다 — 스팟이 차는 순서를 따라가야 링크가 붙는다.
 */
const REGION_ORDER = (process.env.REGION_ORDER ?? '11,41,51')
  .split(',')
  .map((x) => x.trim())
  .filter(Boolean);

const REGNS = [
  '11', '26', '27', '28', '30', '31', '36110', '41',
  '43', '44', '12', '47', '48', '51', '52',
];

type Sigungu = { name: string; areaCd: string; signguCd: string };

/** 처리한 (시군구, baseYm) 을 남긴다. 한도에 걸려도 다음 날 이어받는다. */
const DONE = join(import.meta.dirname, 'data', 'related-done.json');

/**
 * 이미 받은 기록을 지우고 처음부터 다시 받는다. `REDO=1`
 *
 * ⚠ 스팟이 크게 늘었으면 다시 받아야 한다. 연관관광지는 **받을 때의 스팟 이름 색인**으로
 *   맞춰 붙이므로, 색인이 작았을 때 받은 건 붙을 것도 안 붙은 채로 '받음'으로 남는다.
 *   2026-09-06: 색인이 1,000개로 잘린 채 267곳을 다 받아 9만 건 중 300건만 붙었다.
 */
const REDO = process.env.REDO === '1';

async function sigunguList(): Promise<Sigungu[]> {
  const out: Sigungu[] = [];
  for (const regn of REGNS) {
    const url =
      `https://apis.data.go.kr/B551011/KorService2/ldongCode2?serviceKey=${KEY}&${COMMON}` +
      `&numOfRows=100&pageNo=1&lDongRegnCd=${regn}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(20_000) });
    const text = await res.text();
    if (/LIMITED_NUMBER/i.test(text)) throw new Error('일일 요청 제한 초과 (ldongCode2)');
    let items: { code?: string; name?: string }[] = [];
    try {
      const it = JSON.parse(text)?.response?.body?.items?.item;
      items = it ? (Array.isArray(it) ? it : [it]) : [];
    } catch {
      items = [];
    }
    // 세종(36110)처럼 시도 코드가 5자리면 시군구가 자기 자신 하나다.
    const area = regn.slice(0, 2);
    for (const i of items) {
      const c = (i.code ?? '').trim();
      if (!c) continue;
      out.push({ name: i.name ?? c, areaCd: area, signguCd: c.length >= 5 ? c : `${area}${c}` });
    }
  }
  // 스팟이 차는 순서대로. 나머지는 뒤에 붙는다.
  const rank = (s: Sigungu) => {
    const n = REGION_ORDER.indexOf(s.areaCd);
    return n >= 0 ? n : REGION_ORDER.length;
  };
  return out.sort((a, b) => rank(a) - rank(b));
}

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

/**
 * ⚠ 한도에 걸리면 **받아둔 것을 들고 멈춘다.** 던지고 끝내면 그날 받은 게 통째로 날아간다 —
 *   `fetch:spots` 에서 실제로 그렇게 하루치를 잃었다 (2026-09-03).
 */
async function collect(
  baseYm: string,
  list: Sigungu[],
  done: Set<string>,
): Promise<{ rows: Row[]; stopped: boolean }> {
  const out: Row[] = [];
  for (const sg of list) {
    const key = `${sg.signguCd}|${baseYm}`;
    if (done.has(key)) continue;
    let n = 0;
    try {
      for (let p = 1; p <= 30; p++) {
        const rows = await page(sg.areaCd, sg.signguCd, baseYm, p);
        out.push(...rows);
        n += rows.length;
        if (rows.length < 100) break;
      }
    } catch (e) {
      console.log(`\n    중단: ${e instanceof Error ? e.message : e}`);
      return { rows: out, stopped: true };
    }
    done.add(key);
    if (n) console.log(`    ${sg.name} ${n}건`);
  }
  return { rows: out, stopped: false };
}

async function main() {
  if (!KEY) throw new Error('TOURAPI_KEY가 비어 있습니다.');
  const db = supabase();

  // 기본은 최근 확보된 달과 그 3개월 전. 변화를 보려면 시점이 둘 필요하다.
  const months = (process.env.BASE_YM ?? '202606,202603').split(',').map((s) => s.trim());

  // ⚠ 이름 색인이 잘리면 **받은 연관관광지가 우리 스팟과 안 맞는다.**
  //   2026-09-06 까지 1,000개만 색인해서 9만 건을 받고 300건만 붙었다.
  const spotRows = await pageAll<{ id: string; name: string }>((from, to) =>
    db.from('spots').select('id, name').range(from, to),
  );
  const byName = new Map<string, string>();
  for (const s of spotRows ?? []) byName.set(norm(s.name as string), s.id as string);
  console.log(`스팟 ${spotRows.length}건으로 이름 색인`);

  const list = await sigunguList();
  const done = new Set<string>(
    !REDO && existsSync(DONE) ? (JSON.parse(readFileSync(DONE, 'utf-8')) as string[]) : [],
  );
  console.log(`시군구 ${list.length}곳 · 이미 받은 (시군구,월) ${done.size}건`);

  const links: Record<string, unknown>[] = [];
  const rankByMonth = new Map<string, Map<string, number>>(); // baseYm → 'from|to' → rank
  let stopped = false;

  for (const ym of months) {
    if (stopped) break;
    console.log(`\n${ym}:`);
    const got = await collect(ym, list, done);
    const rows = got.rows;
    stopped = got.stopped;
    writeFileSync(DONE, JSON.stringify([...done], null, 0), 'utf-8');
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
  const nameById = new Map(spotRows.map((s) => [s.id as string, s.name as string]));
  console.log(`\n순위가 오른 연결 ${risen.length}건 — 상위 8건:`);
  for (const r of risen.slice(0, 8)) {
    const [f, t] = r.key.split('|');
    console.log(`  ${nameById.get(f)} → ${nameById.get(t)}  ${r.from}위 → ${r.to}위`);
  }
}

/** ⚠ 직접 실행할 때만 돈다 — import 만으로 적재가 도는 사고를 막는다 (2026-09-03). */
if (process.argv[1] !== undefined && import.meta.url.endsWith(basename(process.argv[1]))) {
  main().catch((e) => {
    console.error(e instanceof Error ? e.message : e);
    process.exit(1);
  });
}

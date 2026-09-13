/**
 * 전국전통시장표준데이터 → markets (장날).
 *
 * ⚠ 이 데이터셋은 **오픈API가 없다.** 파일(CSV) 제공만 하고 갱신주기도 연 1회다.
 *   `data/markets.csv`에 두면 읽는다 (data/README.md 참조).
 *
 * ⚠ **시장을 새 스팟으로 만들지 않는다 — 있으면 기존 스팟에 붙인다.**
 *   CSV에는 사진도 개요도 없어서 새로 만들면 신뢰도 25점짜리가 되고, 게이트(60)를 못 넘어
 *   레이더 카드로 뜨질 못한다. 그런데 같은 시장이 TourAPI에는 사진과 개요를 갖고 들어와 있다
 *   (북평민속오일장 85점). 장날만 얹으면 된다.
 *
 * 실행: cd pipeline && npm run fetch:markets
 */

import { basename } from 'node:path';
import { existsSync } from 'node:fs';
import { pageAll } from './lib/page.js';
import { supabase } from './lib/supabase.js';
import { readCsv } from './lib/csv.js';
import { distMeters } from './lib/corridor.js';

const CSV = 'data/markets.csv';
/**
 * 국도 회랑 반경(km). `fetch:spots`와 같은 기준을 쓴다.
 * ⚠ 전에는 12km였고, 판정도 **손으로 찍은 7번 국도 좌표 7개**로 했다.
 *   그래서 전국 CSV를 넣고도 삼척-강릉 것만 걸렸다 (11곳).
 *   이제 `near_routes` RPC가 실제 `routes.geom` 51선으로 판정한다 (2026-09-03).
 */
const CORRIDOR_KM = Number(process.env.CORRIDOR_KM ?? 3.5);

/** 기존 스팟으로 인정할 거리. 표준데이터와 TourAPI의 좌표가 정확히 같지는 않다. */
const MATCH_M = 600;

/**
 * '3일+8일' → [3, 8] · '5일+10일' → [5, 0] · '매일' → null(상설)
 * ⚠ 10·20·30을 그대로 두면 `% 10 = 0`이라 영원히 매칭되지 않는다.
 * 실측 표기 8종: 매일 / 1일+6일 / 2일+7일 / 3일+8일 / 4일+9일 / 5일+10일
 *              / 2일+5일 / 2일+4일+7일+9일
 */
export function normalizeCycle(raw: string): number[] | null {
  const v = (raw ?? '').trim();
  if (!v || v === '매일' || v === '상설') return null;
  const digits = v
    .split('+')
    .map((p) => Number(p.replace(/[^0-9]/g, '')))
    .filter((n) => Number.isInteger(n) && n > 0 && n <= 31)
    .map((n) => n % 10); // 10→0, 20→0, 30→0
  const uniq = [...new Set(digits)].sort((a, b) => a - b);
  return uniq.length ? uniq : null;
}

/**
 * 이름이 시장이라는 말로 **끝나는가** (뒤에 괄호는 허용). 이게 아니면 애초에 후보가 아니다.
 *
 * ⚠ '들어 있는가'로 잡았다가 (2026-09-13) **음식점·먹자골목 10곳이 시장이 됐다** —
 *   봉평장터국밥 · 황룡우시장국밥집 · 국제시장 먹자골목 · 속초관광수산시장 회센터 ….
 *   시장 이름 뒤에 국밥·골목·회센터가 붙은 건 시장 안의 가게지 시장이 아니다. 그런 곳에 장날을
 *   얹으면 카드가 "오늘이 마침 봉평장터국밥이에요"라고 말한다.
 *   제대로 붙는 건 「북평민속오일장 (3, 8일)」「삼척 중앙시장 (2, 7일)」「강릉 동부시장」처럼
 *   시장 이름으로 끝나는 것뿐이다. 나머지는 새 스팟으로 만드는 게 맞다 — 그게 사실이다.
 */
const MARKET_WORD = /(시장|오일장|장터|５일장|5일장)\s*(\(.*?\))?\s*$/;

/**
 * 같은 시장인지.
 *
 * ⚠ 예전에 '앞 두 글자가 같으면'으로 잡았다가 **음식점·축제를 시장으로 바꿔놨다.**
 *   '삼척'·'묵호'·'강릉'이 앞 두 글자라 아무거나 걸렸다
 *   (삼척번개시장 → 삼척동해왕이사부축제, 강릉서부시장 → 강릉 오금집).
 *   그래서 **상대 이름에도 '시장'류 단어가 있어야** 후보로 친다.
 */
function nameLooksSame(csvName: string, spotName: string): boolean {
  if (!MARKET_WORD.test(spotName)) return false;
  const strip = (s: string) =>
    s.replace(/\(.*?\)/g, '').replace(/(전통)?시장|오일장|５일장|5일장|장터|\s/g, '');
  const x = strip(csvName), y = strip(spotName);
  if (!x || !y) return false;
  return x === y || x.includes(y) || y.includes(x);
}

type Spot = { id: string; name: string; lat: number; lng: number; type: string };

async function main() {
  if (!existsSync(CSV)) {
    throw new Error(
      `${CSV}가 없습니다.\n` +
        '  data.go.kr 15012894에서 CSV를 받아 그 경로에 두세요 (data/README.md 참조).',
    );
  }
  const db = supabase();
  const { header, rows } = readCsv(CSV);

  const col = (name: string) => {
    const i = header.findIndex((h) => h.includes(name));
    if (i < 0) throw new Error(`'${name}' 열을 못 찾았습니다. 헤더: ${header.join(' | ')}`);
    return i;
  };
  const [iName, iCycle, iLat, iLng, iAddr, iTel, iType] = [
    col('시장명'), col('시장개설주기'), col('위도'), col('경도'),
    col('소재지도로명주소'), col('전화번호'), col('시장유형'),
  ];

  // 1) 회랑 안 시장만
  const all = rows
    .map((r) => ({
      name: r[iName],
      cycle: normalizeCycle(r[iCycle]),
      rawCycle: r[iCycle],
      lat: Number(r[iLat]),
      lng: Number(r[iLng]),
      addr: r[iAddr] || null,
      tel: r[iTel] || null,
      kind: r[iType] || null,
    }))
    .filter((m) => m.name && Number.isFinite(m.lat) && Number.isFinite(m.lng));

  // 회랑 판정은 실제 노선 선형이 한다 (near_routes RPC). 한 번에 다 던지면 요청이 커서 나눈다.
  const inCorridor: typeof all = [];
  const CHUNK = 300;
  for (let i = 0; i < all.length; i += CHUNK) {
    const slice = all.slice(i, i + CHUNK);
    const { data, error } = await db.rpc('near_routes', {
      p_points: slice.map((m) => [m.lat, m.lng]),
      p_max_km: CORRIDOR_KM,
    });
    if (error) throw new Error(`회랑 판정 실패: ${error.message}`);
    for (const row of (data ?? []) as { idx: number }[]) {
      const m = slice[row.idx];
      if (m) inCorridor.push(m);
    }
  }
  const markets = inCorridor;
  console.log(`전국 ${rows.length}곳 → 좌표 있는 ${all.length}곳 → 회랑 ${CORRIDOR_KM}km 안 ${markets.length}곳`);

  // 2) 붙일 수 있는 기존 스팟을 모은다
  // ⚠ 이 목록이 잘리면 붙일 수 있는 스팟을 못 찾아 **같은 시장을 새로 만든다.**
  //   PostgREST 는 서버가 1,000행에서 끊는다 — limit 으로 못 넘는다.
  const spots = await pageAll<Spot>((from, to) =>
    db.from('spots').select('id, name, lat, lng, type').range(from, to),
  );

  let matched = 0;
  let created = 0;
  const marketRows: Record<string, unknown>[] = [];

  // ⚠ 한 스팟은 한 시장만 차지한다 (2026-09-13). CSV 에 「예산시장」과 「예산상설시장」이 0m 거리로
  //   따로 있어 둘 다 같은 스팟에 붙었고, 마지막 upsert 가 spot_id 중복으로 통째로 실패했다
  //   ("ON CONFLICT DO UPDATE command cannot affect row a second time"). 이미 차지된 스팟은
  //   후보에서 빼고, 두 번째 시장은 제 스팟을 새로 만든다 — 그게 사실이다.
  const claimed = new Set<string>();

  for (const m of markets) {
    const near = spots
      .map((s) => ({ s, d: distMeters(m.lat, m.lng, s.lat, s.lng) }))
      .filter((x) => x.d <= MATCH_M && !claimed.has(x.s.id) && nameLooksSame(m.name, x.s.name))
      .sort((a, b) => a.d - b.d)[0];

    // 지난 실행에서 우리가 만들어둔 스팟이 있으면 그걸 쓴다 (같은 이름 · 200m 안).
    const mine = spots.find(
      (x) =>
        !claimed.has(x.id) && x.name === m.name && distMeters(m.lat, m.lng, x.lat, x.lng) <= 200,
    );

    let spotId: string;
    if (mine) {
      spotId = mine.id;
      matched++;
    } else if (near) {
      spotId = near.s.id;
      // 유형을 market으로 바로잡는다. TourAPI는 시장을 쇼핑/관광지로 넣어둔다.
      if (near.s.type !== 'market') {
        await db.from('spots').update({ type: 'market' }).eq('id', spotId);
      }
      matched++;
      console.log(`  ○ ${m.name} → 기존 스팟 "${near.s.name}" (${Math.round(near.d)}m)`);
    } else {
      // 없으면 만든다. 사진·개요가 없어 신뢰도는 낮게 잡힌다 — 그게 사실이다.
      const trust = (m.tel ? 15 : 0) + (m.addr && /\d/.test(m.addr) ? 10 : 0);
      const { data, error } = await db
        .from('spots')
        .insert({
          type: 'market',
          name: m.name,
          lat: m.lat,
          lng: m.lng,
          geom: `SRID=4326;POINT(${m.lng} ${m.lat})`,
          addr: m.addr,
          tel: m.tel,
          tags: m.kind ? [m.kind] : [],
          trust_score: trust,
        })
        .select('id')
        .single();
      if (error || !data) {
        console.log(`  ✗ ${m.name}: ${error?.message}`);
        continue;
      }
      spotId = data.id;
      created++;
      // 같은 실행 안에서 같은 이름이 또 오면 이걸 다시 쓴다 — 두 번 만들지 않는다.
      spots.push({ id: spotId, name: m.name, lat: m.lat, lng: m.lng, type: 'market' });
    }
    claimed.add(spotId);

    marketRows.push({
      spot_id: spotId,
      open_cycle: m.cycle,
      open_rule: m.cycle ? null : m.rawCycle === '매일' ? null : m.rawCycle,
      note: m.rawCycle,
    });
  }

  // 3) 장날 적재
  const { error: e2 } = await db.from('markets').upsert(marketRows, { onConflict: 'spot_id' });
  if (e2) throw new Error(`markets 적재 실패: ${e2.message}`);

  const fiveDay = marketRows.filter((r) => r.open_cycle);
  console.log(`\n✓ 시장 ${marketRows.length}곳 — 기존 스팟에 붙임 ${matched} · 새로 만듦 ${created}`);
  console.log(`  장날 있는 곳 ${fiveDay.length} · 상설 ${marketRows.length - fiveDay.length}`);

  // 4) 데모 확인 — 북평민속시장 3·8일이 없으면 시연에 쓸 장날이 없다
  const { data: check } = await db
    .from('markets')
    .select('open_cycle, spots(name, trust_score, image_url)')
    .not('open_cycle', 'is', null);
  for (const row of check ?? []) {
    const r = row as unknown as {
      open_cycle: number[];
      spots: { name: string; trust_score: number; image_url: string | null } | null;
    };
    if (!r.spots) continue;
    console.log(
      `  · ${r.spots.name} — 끝자리 ${r.open_cycle.join('·')}일 · ` +
        `${r.spots.trust_score}점 · 사진${r.spots.image_url ? '○' : '✗'}`,
    );
  }
}

/**
 * ⚠ **직접 실행할 때만 돈다.**
 *   전에는 최상위에서 그냥 `main()`을 불렀다. 그래서 다른 스크립트가 이 파일에서
 *   함수 하나(`normalizeCycle`)를 import 하기만 해도 **적재가 통째로 실행됐다** —
 *   2026-09-03 실제로 전국 시장 1,216건이 그렇게 들어왔다 (되돌렸다).
 */
const invokedDirectly =
  process.argv[1] !== undefined && import.meta.url.endsWith(basename(process.argv[1]));
if (invokedDirectly) {
  main().catch((e) => {
    console.error(e instanceof Error ? e.message : e);
    process.exit(1);
  });
}

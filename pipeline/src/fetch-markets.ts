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

import { existsSync } from 'node:fs';
import { supabase } from './lib/supabase.js';
import { readCsv } from './lib/csv.js';
import { distToCorridorKm, distMeters } from './lib/corridor.js';

const CSV = 'data/markets.csv';
const CORRIDOR_KM = Number(process.env.CORRIDOR_KM ?? 12);

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

/** 이름에 시장이라는 말이 들어 있는가. 이게 아니면 애초에 후보가 아니다. */
const MARKET_WORD = /시장|오일장|장터|５일장|5일장/;

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
  const markets = rows
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
    .filter(
      (m) =>
        m.name &&
        Number.isFinite(m.lat) &&
        Number.isFinite(m.lng) &&
        distToCorridorKm(m.lat, m.lng) <= CORRIDOR_KM,
    );
  console.log(`전국 ${rows.length}곳 → 회랑 ${CORRIDOR_KM}km 안 ${markets.length}곳`);

  // 2) 붙일 수 있는 기존 스팟을 모은다
  const { data: spotRows, error: e1 } = await db
    .from('spots')
    .select('id, name, lat, lng, type')
    .limit(5000);
  if (e1) throw new Error(`스팟 조회 실패: ${e1.message}`);
  const spots = (spotRows ?? []) as Spot[];

  let matched = 0;
  let created = 0;
  const marketRows: Record<string, unknown>[] = [];

  for (const m of markets) {
    const near = spots
      .map((s) => ({ s, d: distMeters(m.lat, m.lng, s.lat, s.lng) }))
      .filter((x) => x.d <= MATCH_M && nameLooksSame(m.name, x.s.name))
      .sort((a, b) => a.d - b.d)[0];

    // 지난 실행에서 우리가 만들어둔 스팟이 있으면 그걸 쓴다 (같은 이름 · 200m 안).
    const mine = spots.find(
      (x) => x.name === m.name && distMeters(m.lat, m.lng, x.lat, x.lng) <= 200,
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
    }

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

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

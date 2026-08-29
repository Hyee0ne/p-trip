/**
 * 천문연 출몰시각 → sun_moon (좌표 격자 × 날짜 캐시).
 *
 * 일몰만 받는 게 아니다. **월출·월몰·박명 3종을 한 응답에 같이 준다**(2026-08-29 실측).
 * 일몰은 §3.1 타이밍 가중치(뷰포인트 ×2)에, 월출·월몰·천문박명은 §3.8 별 보기 좋은 밤에 쓴다.
 *
 * ⚠ 격자는 **스팟이 실제로 있는 칸만** 만든다. 빈 바다·산을 채울 이유가 없다.
 * ⚠ 이동 중에 다시 조회하지 않는다. 파이프라인이 미리 채워두고 앱은 읽기만 한다.
 *
 * 실행: cd pipeline && npm run fetch:sunset
 *       DAYS=60 npm run fetch:sunset
 */

import { supabase } from './lib/supabase.js';

const KEY = process.env.DATA_GO_KR_KEY?.trim();
const BASE = 'https://apis.data.go.kr/B090041/openapi/service/RiseSetInfoService';

/** 며칠치를 미리 채울지. 장날·일몰 카드는 앞날을 알아야 미리 말을 건다. */
const DAYS = Number(process.env.DAYS ?? 45);

/** 격자 크기(도). 0.1도면 일몰 시각 차이가 1분 안쪽이라 충분하다. */
const GRID = 0.1;

const round1 = (n: number) => Math.round(n / GRID) * GRID;
const yyyymmdd = (d: Date) =>
  `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** 'HHMM' → 'HH:MM'. 빈 값·'-'은 null (그날 안 뜨거나 안 지는 경우가 있다). */
function hhmm(raw: string | undefined): string | null {
  const v = (raw ?? '').trim();
  if (!/^\d{4}$/.test(v)) return null;
  return `${v.slice(0, 2)}:${v.slice(2)}`;
}

function tag(xml: string, name: string): string | undefined {
  return xml.match(new RegExp(`<${name}>([\\s\\S]*?)</${name}>`))?.[1];
}

let quotaHit = false;

async function riseSet(lat: number, lng: number, date: Date): Promise<Record<string, string | null> | null> {
  const url =
    `${BASE}/getLCRiseSetInfo?serviceKey=${KEY}&locdate=${yyyymmdd(date)}` +
    `&longitude=${lng.toFixed(2)}&latitude=${lat.toFixed(2)}&dnYn=Y`;
  for (let n = 1; n <= 3; n++) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(15_000) });
      const xml = await res.text();
      if (/LIMITED_NUMBER/i.test(xml)) {
        quotaHit = true;
        return null;
      }
      if (!tag(xml, 'sunset')) return null;
      return {
        sunrise: hhmm(tag(xml, 'sunrise')),
        suntransit: hhmm(tag(xml, 'suntransit')),
        sunset: hhmm(tag(xml, 'sunset')),
        moonrise: hhmm(tag(xml, 'moonrise')),
        moontransit: hhmm(tag(xml, 'moontransit')),
        moonset: hhmm(tag(xml, 'moonset')),
        civil_dawn: hhmm(tag(xml, 'civilm')),
        civil_dusk: hhmm(tag(xml, 'civile')),
        naut_dawn: hhmm(tag(xml, 'nautm')),
        naut_dusk: hhmm(tag(xml, 'naute')),
        astro_dawn: hhmm(tag(xml, 'astm')),
        astro_dusk: hhmm(tag(xml, 'aste')),
      };
    } catch {
      if (n === 3) return null;
      await new Promise((r) => setTimeout(r, 400 * n));
    }
  }
  return null;
}

async function main() {
  if (!KEY) throw new Error('DATA_GO_KR_KEY가 비어 있습니다.');
  const db = supabase();

  // 1) 스팟이 있는 격자만 추린다.
  const { data: spots, error } = await db.from('spots').select('lat, lng').limit(5000);
  if (error) throw new Error(`스팟 조회 실패: ${error.message}`);
  const grids = new Map<string, { lat: number; lng: number }>();
  for (const s of spots ?? []) {
    const lat = round1(s.lat as number);
    const lng = round1(s.lng as number);
    grids.set(`${lat.toFixed(1)},${lng.toFixed(1)}`, { lat, lng });
  }
  console.log(`스팟 ${spots?.length ?? 0}건 → 격자 ${grids.size}칸`);

  // 2) 이미 있는 (날짜, 격자)는 건너뛴다. 하루 한도를 아껴 이어받는다.
  const today = new Date();
  const dates = Array.from({ length: DAYS }, (_, i) => {
    const d = new Date(today);
    d.setDate(d.getDate() + i);
    return d;
  });
  const { data: have } = await db
    .from('sun_moon')
    .select('locdate, grid_lat, grid_lng')
    .gte('locdate', iso(dates[0]))
    .lte('locdate', iso(dates[dates.length - 1]));
  const done = new Set(
    (have ?? []).map((r) => `${r.locdate}|${Number(r.grid_lat).toFixed(1)},${Number(r.grid_lng).toFixed(1)}`),
  );

  const jobs: { date: Date; key: string; lat: number; lng: number }[] = [];
  for (const d of dates) {
    for (const [key, g] of grids) {
      if (done.has(`${iso(d)}|${key}`)) continue;
      jobs.push({ date: d, key, lat: g.lat, lng: g.lng });
    }
  }
  console.log(`${DAYS}일 × ${grids.size}칸 = ${dates.length * grids.size}건 중 받을 것 ${jobs.length}건`);
  if (!jobs.length) {
    console.log('· 이미 다 채워져 있습니다.');
    return;
  }

  // 3) 받아서 넣는다.
  const rows: Record<string, unknown>[] = [];
  const LANES = 6;
  for (let i = 0; i < jobs.length && !quotaHit; i += LANES) {
    const batch = jobs.slice(i, i + LANES);
    const got = await Promise.all(
      batch.map(async (j) => ({ j, v: await riseSet(j.lat, j.lng, j.date) })),
    );
    for (const { j, v } of got) {
      if (!v) continue;
      rows.push({ locdate: iso(j.date), grid_lat: j.lat.toFixed(1), grid_lng: j.lng.toFixed(1), ...v });
    }
    if (rows.length && rows.length % 120 === 0) {
      await db.from('sun_moon').upsert(rows.splice(0), { onConflict: 'locdate,grid_lat,grid_lng' });
      console.log(`  ${Math.min(i + LANES, jobs.length)}/${jobs.length}`);
    }
  }
  if (rows.length) {
    const { error: e2 } = await db
      .from('sun_moon')
      .upsert(rows, { onConflict: 'locdate,grid_lat,grid_lng' });
    if (e2) throw new Error(`sun_moon 적재 실패: ${e2.message}`);
  }

  // 4) 확인 — 오늘 데모 격자의 일몰과 '달 없는 밤' 판정
  const { data: sample } = await db
    .from('sun_moon')
    .select('locdate, sunset, astro_dusk, moonrise, moonset')
    .eq('grid_lat', '37.5')
    .eq('grid_lng', '129.1')
    .order('locdate')
    .limit(7);
  console.log('\n✓ 적재 완료. 동해 격자(37.5, 129.1) 일주일:');
  for (const r of sample ?? []) {
    console.log(
      `  ${r.locdate}  일몰 ${r.sunset}  천문박명 ${r.astro_dusk}  ` +
        `월출 ${r.moonrise ?? '  -  '}  월몰 ${r.moonset ?? '  -  '}`,
    );
  }
  if (quotaHit) console.log('\n⚠ 일일 요청 제한에 닿아 멈췄습니다. 다시 돌리면 이어받습니다.');
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

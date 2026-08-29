/**
 * 데이터 검수 — **데모를 실제로 깨뜨릴 것**만 본다.
 *
 * 통계를 예쁘게 뽑는 게 목적이 아니다. 시연 당일에 "카드가 안 뜬다", "장날이 틀렸다",
 * "지도에 선이 없다"가 되는 조건을 미리 잡는다.
 * 치명적인 게 하나라도 걸리면 종료코드 1로 끝난다 — CI나 사람 눈이 놓치지 않게.
 *
 * 실행: cd pipeline && npm run verify
 */

import { supabase } from './lib/supabase.js';

type Level = 'fail' | 'warn' | 'ok';
const results: { level: Level; name: string; note: string }[] = [];

function report(level: Level, name: string, note: string) {
  results.push({ level, name, note });
  const mark = level === 'fail' ? '✗' : level === 'warn' ? '△' : '✓';
  console.log(`${mark} ${name}\n    ${note}`);
}

/** 데모 대본에 이름이 나오는 스팟. 하나라도 없으면 시연이 성립하지 않는다. */
const DEMO_SPOTS = ['북평민속', '추암', '묵호등대', '어달'];

async function main() {
  const db = supabase();
  const count = async (table: string, q?: (b: any) => any) => {
    let b = db.from(table).select('*', { count: 'exact', head: true });
    if (q) b = q(b);
    const { count: n, error } = await b;
    if (error) throw new Error(`${table}: ${error.message}`);
    return n ?? 0;
  };

  console.log('P의 여행 — 데이터 검수\n');

  // ── 1. 노선 ─────────────────────────────────────────────
  const routes = await count('routes');
  const withGeom = await count('routes', (b) => b.not('geom', 'is', null));
  report(
    routes === 51 ? (withGeom >= 50 ? 'ok' : 'warn') : 'fail',
    '국도 51선',
    `${routes}개 · 선형 있는 것 ${withGeom}개` +
      (withGeom < routes ? ` (없는 것 ${routes - withGeom}개 — 앱에서 지도에 안 그려진다)` : ''),
  );

  // ── 2. 스팟 ─────────────────────────────────────────────
  const spots = await count('spots');
  const gated = await count('spots', (b) => b.gte('trust_score', 60));
  const radar = await count('spots', (b) => b.gte('trust_score', 60).lte('detour_min', 10));
  report(
    radar >= 20 ? 'ok' : radar > 0 ? 'warn' : 'fail',
    '레이더 카드 후보',
    `스팟 ${spots}건 · 게이트(60) 통과 ${gated}건 · 국도 10분 이내까지 ${radar}건` +
      (radar < 20 ? ' — 후보가 적으면 주행 중에 카드가 안 뜬다' : ''),
  );

  const noRoute = await count('spots', (b) => b.is('route_id', null));
  report(
    noRoute === 0 ? 'ok' : 'warn',
    '진출점 계산',
    noRoute === 0
      ? '모든 스팟에 노선·진출점이 붙었다'
      : `${noRoute}건에 route_id가 없다 — compute_spot_exits()를 다시 돌릴 것`,
  );

  // 결측률 — 화면이 비어 보이는 원인
  const noPhoto = await count('spots', (b) => b.is('image_url', null));
  const noHours = await count('spots', (b) => b.is('open_hours', null));
  const noOverview = await count('spots', (b) => b.is('overview', null));
  report(
    noPhoto / spots < 0.5 ? 'ok' : 'warn',
    '결측률',
    `사진 없음 ${pct(noPhoto, spots)} · 영업시간 없음 ${pct(noHours, spots)} · 개요 없음 ${pct(noOverview, spots)}` +
      (noPhoto / spots >= 0.5 ? ' — 전면 카드가 색면으로 뜨는 비율이 높다' : ''),
  );

  // ── 3. 데모 스팟 ────────────────────────────────────────
  const missing: string[] = [];
  for (const kw of DEMO_SPOTS) {
    const { data } = await db.from('spots').select('name').ilike('name', `%${kw}%`).limit(1);
    if (!data?.length) missing.push(kw);
  }
  report(
    missing.length === 0 ? 'ok' : 'fail',
    '데모 대본 스팟',
    missing.length === 0
      ? `${DEMO_SPOTS.join(' · ')} 전부 있다`
      : `없는 것: ${missing.join(', ')} — 시연 대본을 고치거나 수집 범위를 넓혀야 한다`,
  );

  // ── 4. 장날 ─────────────────────────────────────────────
  const { data: mkts } = await db
    .from('markets')
    .select('open_cycle, spots(name)')
    .not('open_cycle', 'is', null);
  const fiveDay = (mkts ?? []) as unknown as {
    open_cycle: number[];
    spots: { name: string } | null;
  }[];
  report(
    fiveDay.length > 0 ? 'ok' : 'fail',
    '장날 있는 시장',
    fiveDay.length
      ? fiveDay.map((m) => `${m.spots?.name ?? '?'}(${m.open_cycle.join('·')}일)`).join(' · ')
      : '장날 있는 시장이 없다 — "오늘만 열리는 발견"의 핵심 소재가 빈다',
  );

  // ⚠ 월말 오판. 31일은 %10 = 1이다. 끝자리 0인 장(10·20·30일)이 31일에 서면 안 된다.
  const bad: string[] = [];
  for (const m of fiveDay) {
    if (!m.open_cycle.includes(0)) continue;
    const { data } = await db.rpc('is_market_day', { open_cycle: m.open_cycle, d: '2026-01-31' });
    if (data === true) bad.push(m.spots?.name ?? '?');
  }
  report(
    bad.length === 0 ? 'ok' : 'fail',
    '월말 장날 오판',
    bad.length === 0
      ? '끝자리 0인 장이 31일에 서지 않는다 (정규화가 제대로 됐다)'
      : `31일을 장날로 오판: ${bad.join(', ')}`,
  );

  // ── 5. 해·달 캐시 ───────────────────────────────────────
  const today = new Date().toISOString().slice(0, 10);
  const ahead = new Date(Date.now() + 14 * 864e5).toISOString().slice(0, 10);
  const sun = await count('sun_moon', (b) => b.gte('locdate', today).lte('locdate', ahead));
  const grids = new Set(
    ((await db.from('sun_moon').select('grid_lat, grid_lng').eq('locdate', today)).data ?? []).map(
      (r) => `${r.grid_lat},${r.grid_lng}`,
    ),
  ).size;
  report(
    grids > 0 && sun > 0 ? 'ok' : 'fail',
    '해·달 캐시',
    `오늘부터 2주 ${sun}건 · 오늘 격자 ${grids}칸` +
      (grids === 0 ? ' — 일몰 타이밍과 별 보기 판정이 통째로 안 된다' : ''),
  );

  // ── 6. 천문현상 ─────────────────────────────────────────
  const astroAll = await count('astro_events');
  const astroShow = await count('astro_events', (b) => b.eq('is_event', true));
  report(
    astroShow > 0 ? 'ok' : 'warn',
    '천문현상',
    `${astroAll}건 중 노출용 ${astroShow}건 (나머지는 월상 달력이라 화면에 띄우지 않는다)`,
  );

  // ── 7. 발자국 ───────────────────────────────────────────
  const { data: yms } = await db.from('spot_links').select('base_ym');
  const months = new Set((yms ?? []).map((r) => r.base_ym as string));
  const { data: rising } = await db.rpc('rising_spots', { p_limit: 50 });
  report(
    months.size >= 2 && (rising as unknown[])?.length > 0 ? 'ok' : 'warn',
    '요즘 차들이 몰래 가는 곳',
    `시점 ${months.size}개(${[...months].join(', ')}) · 순위 오른 연결 ${(rising as unknown[])?.length ?? 0}건` +
      (months.size < 2 ? ' — 시점이 둘이어야 변화를 낼 수 있다' : ''),
  );

  // ── 8. 코스 ─────────────────────────────────────────────
  const courses = await count('courses');
  const onCourse = await count('spots', (b) =>
    b.not('exit_frac', 'is', null).gte('trust_score', 60).lte('detour_min', 10),
  );
  report(
    courses > 0 && onCourse >= 10 ? 'ok' : courses > 0 ? 'warn' : 'fail',
    '코스',
    `${courses}개 · 코스 위 발견(게이트·10분) ${onCourse}건` +
      (courses === 0 ? ' — CO-02가 빈 화면이 된다' : ''),
  );

  // ── 마무리 ──────────────────────────────────────────────
  const fails = results.filter((r) => r.level === 'fail');
  const warns = results.filter((r) => r.level === 'warn');
  console.log(
    `\n───\n${results.length}개 항목 · 통과 ${results.length - fails.length - warns.length} · 주의 ${warns.length} · 실패 ${fails.length}`,
  );
  if (fails.length) {
    console.log(`\n시연을 막는 것:\n${fails.map((f) => `  · ${f.name}`).join('\n')}`);
    process.exit(1);
  }
}

const pct = (n: number, total: number) =>
  total === 0 ? '-' : `${n}건 (${Math.round((n / total) * 100)}%)`;

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

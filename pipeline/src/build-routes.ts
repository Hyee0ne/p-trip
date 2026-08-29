/**
 * 국도 51선 메타 시드 + 노선 선형(LineString) 적재.
 *
 * 두 단계로 나뉜다:
 *  1. **메타** — 51선 번호·별명·축·주행가능·기종점. 손으로 큐레이션한 값이라 파일로 갖고 있다.
 *     외부 의존 없이 항상 돈다.
 *  2. **선형** — 국토교통부 일반국도 도로중심선 SHP에서 노선번호로 뽑아 4326으로 변환해 넣는다.
 *     파일이 있어야 돈다. 없으면 메타만 넣고 조용히 넘어간다 — 없는 선을 지어내지 않는다.
 *
 * 실행: cd pipeline && npm run build:routes
 */

import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { open as openShapefile } from 'shapefile';
import proj4 from 'proj4';

import { supabase } from './lib/supabase.js';
import routesMeta from './data/routes-meta.json' with { type: 'json' };

/** 도로중심선 SHP를 풀어둔 곳. data/README.md 참조. */
const SHP_DIR = 'data/roads';

/** 데모 구간 — 7번 국도 삼척–강릉. 이 범위 밖은 지금 안 넣는다 (§데모 기준 데이터). */
const DEMO = { minLat: 37.3, maxLat: 37.9, minLng: 128.7, maxLng: 129.5 };

type Meta = { id: number; name: string; axis: string; drivable: boolean; from_to: string };

async function seedMeta() {
  const db = supabase();
  const rows = (routesMeta as Meta[]).map((r) => ({
    id: r.id,
    name: r.name,
    axis: r.axis,
    drivable: r.drivable,
    from_to: r.from_to,
  }));
  const { error } = await db.from('routes').upsert(rows, { onConflict: 'id' });
  if (error) throw new Error(`routes 메타 적재 실패: ${error.message}`);

  const ns = rows.filter((r) => r.axis === 'NS').length;
  console.log(`✓ 51선 메타 적재 — 남북 ${ns} · 동서 ${rows.length - ns}`);
  console.log(`  별명 ${rows.filter((r) => r.name).length}개 · 주행불가 ${rows.filter((r) => !r.drivable).length}개`);
}

/** .prj의 WKT를 읽어 좌표계를 잡는다. 추측하지 않는다 — 파일이 알려준다. */
function projectionOf(dir: string, base: string): string {
  const prj = join(dir, `${base}.prj`);
  if (!existsSync(prj)) {
    throw new Error(`${base}.prj가 없습니다. 좌표계를 알 수 없어 변환할 수 없습니다.`);
  }
  return readFileSync(prj, 'utf8').trim();
}

/**
 * 노선번호.
 * ⚠ '일련번호' 같은 필드가 먼저 걸리면 엉뚱한 번호가 들어간다. **정확한 이름을 먼저 본다.**
 */
function routeNumberOf(props: Record<string, unknown>): number | null {
  const exact = props['노선번호'] ?? props['ROUTE_NO'] ?? props['route_no'];
  const pick = (v: unknown) => {
    const n = Number(String(v ?? '').replace(/[^0-9]/g, ''));
    return Number.isInteger(n) && n > 0 && n < 1000 ? n : null;
  };
  if (exact !== undefined) return pick(exact);
  for (const [k, v] of Object.entries(props)) {
    if (!/^(route|rte)/i.test(k)) continue;
    const n = pick(v);
    if (n !== null) return n;
  }
  return null;
}

function inDemoBox(coords: number[][]): boolean {
  return coords.some(
    ([lng, lat]) =>
      lat >= DEMO.minLat && lat <= DEMO.maxLat && lng >= DEMO.minLng && lng <= DEMO.maxLng,
  );
}

/**
 * 이어지는 조각끼리 붙여 **여러 갈래**로 돌려준다.
 * ⚠ 하나로 합치려 들면 안 된다. 국도는 도심 통과·우회·미개통으로 실제로 끊겨 있어서,
 *   한 갈래만 남기면 노선 대부분을 버리게 된다.
 */
function mergeParts(parts: number[][][]): number[][][] {
  const remaining = [...parts];
  const chains: number[][][] = [];
  const near = (a: number[], b: number[]) =>
    Math.abs(a[0] - b[0]) < 0.002 && Math.abs(a[1] - b[1]) < 0.002; // 약 200m

  while (remaining.length) {
    const chain = remaining.shift()!;
    let joined = true;
    while (joined && remaining.length) {
      joined = false;
      for (let i = 0; i < remaining.length; i++) {
        const p = remaining[i];
        if (near(chain[chain.length - 1], p[0])) chain.push(...p.slice(1));
        else if (near(chain[chain.length - 1], p[p.length - 1]))
          chain.push(...[...p].reverse().slice(1));
        else if (near(chain[0], p[p.length - 1])) chain.unshift(...p.slice(0, -1));
        else if (near(chain[0], p[0])) chain.unshift(...[...p].reverse().slice(0, -1));
        else continue;
        remaining.splice(i, 1);
        joined = true;
        break;
      }
    }
    if (chain.length >= 2) chains.push(chain);
  }
  return chains;
}

/** 점을 솎아낸다. 지도에 그리는 용도라 1m 단위가 필요 없다. 0.0005도 ≈ 50m. */
function simplify(coords: number[][], tolerance = 0.0005): number[][] {
  if (coords.length < 3) return coords;
  const out = [coords[0]];
  for (const c of coords.slice(1, -1)) {
    const last = out[out.length - 1];
    if (Math.abs(c[0] - last[0]) > tolerance || Math.abs(c[1] - last[1]) > tolerance) out.push(c);
  }
  out.push(coords[coords.length - 1]);
  return out;
}

async function loadGeometry() {
  if (!existsSync(SHP_DIR)) {
    console.log(`\n· 선형 건너뜀 — ${SHP_DIR}/ 가 없다.`);
    console.log('  국토교통부 일반국도 도로중심선(data.go.kr 15122482) ZIP을 풀어 두면 적재한다.');
    console.log('  없어도 앱은 돈다 — 지도에 선만 안 그려진다.');
    return;
  }

  const shp = readdirSync(SHP_DIR).find((f) => f.toLowerCase().endsWith('.shp'));
  if (!shp) {
    console.log(`\n⚠ ${SHP_DIR}/ 에 .shp 파일이 없다.`);
    return;
  }
  const base = shp.replace(/\.shp$/i, '');
  const wkt = projectionOf(SHP_DIR, base);
  const toWgs84 = proj4(wkt, 'EPSG:4326');
  console.log(`\n원본 좌표계: ${wkt.slice(0, 60)}…`);

  // ⚠ .dbf 인코딩을 안 주면 한글 필드명이 깨져서 '노선번호'를 못 찾는다. .cpg가 알려준다.
  const cpg = existsSync(join(SHP_DIR, `${base}.cpg`))
    ? readFileSync(join(SHP_DIR, `${base}.cpg`), 'utf8').trim().toLowerCase()
    : 'utf-8';
  console.log(`속성 인코딩: ${cpg}`);

  // 노선번호별로 조각을 모은다. **전국을 다 넣는다** —
  // exit_frac·detour_min 계산이 전국 노선을 필요로 하고, 앱은 가까운 노선만 골라 받는다.
  const byRoute = new Map<number, number[][][]>();
  const kmByRoute = new Map<number, number>();
  const source = await openShapefile(
    join(SHP_DIR, `${base}.shp`),
    join(SHP_DIR, `${base}.dbf`),
    { encoding: cpg },
  );
  let total = 0;
  let inDemo = 0;

  for (let r = await source.read(); !r.done; r = await source.read()) {
    const f = r.value as { properties: Record<string, unknown>; geometry: unknown };
    total++;
    const no = routeNumberOf(f.properties);
    if (no === null) continue;

    // 상·하행이 나란히 두 줄로 들어 있다. 상행만 쓴다 — 안 그러면 선이 겹쳐 보이고 길이가 두 배가 된다.
    if (String(f.properties['상하행'] ?? '1') !== '1') continue;

    const len = Number(f.properties['영역길이'] ?? 0);
    if (Number.isFinite(len)) kmByRoute.set(no, (kmByRoute.get(no) ?? 0) + len / 1000);

    const g = f.geometry as { type: string; coordinates: number[][] | number[][][] } | null;
    if (!g) continue;
    const lines: number[][][] =
      g.type === 'LineString'
        ? [g.coordinates as number[][]]
        : g.type === 'MultiLineString'
          ? (g.coordinates as number[][][])
          : [];

    for (const line of lines) {
      const wgs = line.map((c) => toWgs84.forward([c[0], c[1]]));
      if (inDemoBox(wgs)) inDemo++;
      if (!byRoute.has(no)) byRoute.set(no, []);
      byRoute.get(no)!.push(wgs);
    }
  }
  console.log(`  피처 ${total.toLocaleString()}개 → 노선 ${byRoute.size}개 (데모 구간에 걸친 조각 ${inDemo}개)`);

  const db = supabase();
  let okCount = 0;
  let points = 0;
  for (const [no, parts] of [...byRoute].sort((a, b) => a[0] - b[0])) {
    const chains = mergeParts(parts).map((c) => simplify(c)).filter((c) => c.length >= 2);
    if (!chains.length) continue;
    const km = kmByRoute.get(no);
    const { error } = await db
      .from('routes')
      .update({
        geom: `SRID=4326;${toWkt(chains)}`,
        ...(km ? { total_km: Math.round(km) } : {}),
      })
      .eq('id', no);
    if (error) {
      console.log(`  ✗ ${no}번: ${error.message}`);
      continue;
    }
    const n = chains.reduce((a, c) => a + c.length, 0);
    okCount++;
    points += n;
    console.log(
      `  ✓ ${String(no).padStart(2)}번 — 갈래 ${String(chains.length).padStart(2)}개 · 점 ${String(n).padStart(5)}개` +
        (km ? ` · ${Math.round(km)}km` : ''),
    );
  }
  console.log(`\n노선 ${okCount}개 · 점 ${points.toLocaleString()}개 적재`);
}

/** 끊긴 국도를 그대로 담는다 — 한 갈래로 억지로 잇지 않는다. */
function toWkt(chains: number[][][]): string {
  const parts = chains.map(
    (c) => `(${c.map(([x, y]) => `${x.toFixed(6)} ${y.toFixed(6)}`).join(',')})`,
  );
  return `MULTILINESTRING(${parts.join(',')})`;
}

async function main() {
  await seedMeta();
  await loadGeometry();
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

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

/** 노선번호 후보 필드. 데이터셋마다 이름이 달라서 여러 개를 본다. */
function routeNumberOf(props: Record<string, unknown>): number | null {
  for (const [k, v] of Object.entries(props)) {
    if (!/route|노선|rte|번호|no/i.test(k)) continue;
    const n = Number(String(v).replace(/[^0-9]/g, ''));
    if (Number.isInteger(n) && n > 0 && n < 1000) return n;
  }
  return null;
}

function inDemoBox(coords: number[][]): boolean {
  return coords.some(
    ([lng, lat]) =>
      lat >= DEMO.minLat && lat <= DEMO.maxLat && lng >= DEMO.minLng && lng <= DEMO.maxLng,
  );
}

/** 같은 노선의 조각들을 이어 붙인다. 도로중심선은 상·하행과 구간이 잘게 쪼개져 있다. */
function mergeParts(parts: number[][][]): number[][] {
  if (parts.length === 0) return [];
  const remaining = [...parts];
  const merged = remaining.shift()!;
  const near = (a: number[], b: number[]) =>
    Math.abs(a[0] - b[0]) < 0.002 && Math.abs(a[1] - b[1]) < 0.002; // 약 200m

  let joined = true;
  while (joined && remaining.length) {
    joined = false;
    for (let i = 0; i < remaining.length; i++) {
      const p = remaining[i];
      if (near(merged[merged.length - 1], p[0])) {
        merged.push(...p.slice(1));
      } else if (near(merged[merged.length - 1], p[p.length - 1])) {
        merged.push(...[...p].reverse().slice(1));
      } else if (near(merged[0], p[p.length - 1])) {
        merged.unshift(...p.slice(0, -1));
      } else if (near(merged[0], p[0])) {
        merged.unshift(...[...p].reverse().slice(0, -1));
      } else {
        continue;
      }
      remaining.splice(i, 1);
      joined = true;
      break;
    }
  }
  if (remaining.length) {
    console.log(`  ⚠ 이어 붙이지 못한 조각 ${remaining.length}개 — 노선이 끊겨 있을 수 있다`);
  }
  return merged;
}

/** 점을 솎아낸다. 지도에 그리는 용도라 1m 단위가 필요 없다. */
function simplify(coords: number[][], tolerance = 0.0002): number[][] {
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

  // 노선번호별로 조각을 모은다.
  const byRoute = new Map<number, number[][][]>();
  const source = await openShapefile(join(SHP_DIR, `${base}.shp`), join(SHP_DIR, `${base}.dbf`));
  let total = 0;

  for (let r = await source.read(); !r.done; r = await source.read()) {
    const f = r.value as { properties: Record<string, unknown>; geometry: unknown };
    total++;
    const no = routeNumberOf(f.properties);
    if (no === null) continue;

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
      if (!inDemoBox(wgs)) continue; // 데모 구간만. 전국은 시드 용량이 커진다
      if (!byRoute.has(no)) byRoute.set(no, []);
      byRoute.get(no)!.push(wgs);
    }
  }
  console.log(`  피처 ${total.toLocaleString()}개 중 데모 구간에 걸친 노선 ${byRoute.size}개`);

  const db = supabase();
  for (const [no, parts] of [...byRoute].sort((a, b) => a[0] - b[0])) {
    const merged = simplify(mergeParts(parts));
    if (merged.length < 2) continue;
    const geojson = { type: 'LineString', coordinates: merged };
    const { error } = await db
      .from('routes')
      .update({ geom: `SRID=4326;${toWkt(merged)}` })
      .eq('id', no);
    if (error) {
      console.log(`  ✗ ${no}번: ${error.message}`);
      continue;
    }
    console.log(`  ✓ ${no}번 국도 — 조각 ${parts.length}개 → 점 ${merged.length}개`);
    void geojson;
  }
}

function toWkt(coords: number[][]): string {
  return `LINESTRING(${coords.map(([x, y]) => `${x.toFixed(6)} ${y.toFixed(6)}`).join(',')})`;
}

async function main() {
  await seedMeta();
  await loadGeometry();
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

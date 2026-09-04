/**
 * 국도 진출점 계산 — `route_id` · `exit_geom` · `exit_frac` · `detour_min`.
 *
 * ⚠ **스팟을 받은 뒤 반드시 돌려야 한다.** 이게 비어 있으면 `detour_min <= 10` 필터에 걸려
 *   레이더에 **아예 안 뜬다.** 2026-09-04: 하루치 999건이 그 상태로 하루를 보냈다 —
 *   받아놓고 앱에서 한 곳도 안 보였다.
 *
 * ⚠ 배치 함수다. 남은 게 0이 될 때까지 반복해서 부른다.
 *
 * 실행: cd pipeline && npm run compute:exits
 */

import { basename } from 'node:path';
import { supabase } from './lib/supabase.js';

/** 한 번에 처리할 건수. 너무 키우면 PostGIS 문장이 타임아웃에 걸린다. */
const BATCH = Number(process.env.BATCH ?? 200);

/** 이 거리 안에서 가장 가까운 노선을 찾는다. */
const MAX_KM = Number(process.env.MAX_KM ?? 20);

/** 무한 반복 방어. 한 번에 BATCH건이니 이 정도면 4만 건이다. */
const MAX_ROUNDS = 200;

async function main() {
  const db = supabase();
  let total = 0;

  for (let round = 1; round <= MAX_ROUNDS; round++) {
    const { data, error } = await db.rpc('compute_spot_exits', {
      batch: BATCH,
      max_km: MAX_KM,
    });
    if (error) throw new Error(`진출점 계산 실패: ${error.message}`);

    const row = (data as { updated: number; remaining: number }[])[0];
    if (!row) break;
    total += row.updated;
    console.log(`  갱신 ${String(row.updated).padStart(4)}  남은 ${row.remaining}`);

    // 남은 게 없거나 더 못 채우면 끝. updated 0 인데 remaining 이 남으면
    // 20km 안에 노선이 없는 것들이다 — 반복해도 소용없다.
    if (row.remaining === 0 || row.updated === 0) break;
  }

  console.log(`\n✓ 진출점 ${total}건 계산`);
}

/** ⚠ 직접 실행할 때만 돈다 — import 만으로 적재가 도는 사고를 막는다 (2026-09-03). */
if (process.argv[1] !== undefined && import.meta.url.endsWith(basename(process.argv[1]))) {
  main().catch((e) => {
    console.error(e instanceof Error ? e.message : e);
    process.exit(1);
  });
}

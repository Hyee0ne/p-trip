/**
 * 코스 = 노선의 **큐레이션** 구간 (TECH_SPEC §2).
 *
 * ⚠ 노선을 기계적으로 N등분하지 않는다. 그건 큐레이션이 아니라 토막이다.
 *   데모 구간 하나를 제대로 만들고, 나머지는 사람이 정할 때 늘린다.
 *   코스 없는 노선은 앱에서 "이 길의 코스를 준비하고 있어요"로 뜬다 — 그게 사실이다.
 *
 * 실행: cd pipeline && npm run build:courses
 */

import { supabase } from './lib/supabase.js';

/** 손으로 정한 코스. 문구는 기획 카피 그대로다 (앱 픽스처와 같은 값). */
const COURSES = [
  {
    id: '7d0e6a2c-0000-4000-8000-000000000007',
    routeId: 7,
    title: '동해 바닷길',
    start: '삼척',
    end: '강릉',
    blurb: '삼척에서 강릉까지, 바다만 보고 달리는 길',
    // 7번 국도 해안 구간만 자르는 범위. 내륙으로 빠지는 갈래를 배제한다.
    box: { minLat: 37.40, maxLat: 37.80, minLng: 128.85, maxLng: 129.30 },
  },
];

async function main() {
  const db = supabase();

  for (const c of COURSES) {
    const { data, error } = await db.rpc('upsert_course_from_route', {
      p_id: c.id,
      p_route_id: c.routeId,
      p_title: c.title,
      p_start: c.start,
      p_end: c.end,
      p_blurb: c.blurb,
      p_min_lat: c.box.minLat,
      p_max_lat: c.box.maxLat,
      p_min_lng: c.box.minLng,
      p_max_lng: c.box.maxLng,
    });
    if (error) throw new Error(`${c.title}: ${error.message}`);
    const r = (data as { km: number; minutes: number; points: number }[])[0];
    console.log(`✓ ${c.title} (${c.routeId}번) — ${r.km}km · 순수 주행 ${r.minutes}분 · 점 ${r.points}개`);

    // 코스 선형이 생겼으니 진출로 역산(§3.1)의 전제인 exit_frac을 채운다.
    const { data: f, error: e2 } = await db.rpc('compute_exit_frac', { p_course_id: c.id });
    if (e2) throw new Error(`exit_frac: ${e2.message}`);
    console.log(`  exit_frac ${(f as { updated: number }[])[0].updated}건`);
  }

  // 확인 — 코스를 지나는 순서대로 발견이 늘어서는지
  const { data: spots } = await db
    .from('spots')
    .select('name, type, exit_frac, detour_min, trust_score')
    .not('exit_frac', 'is', null)
    .gte('trust_score', 60)
    .lte('detour_min', 10)
    .order('exit_frac')
    .limit(12);
  console.log('\n코스를 지나는 순서 (게이트 통과 · 국도 10분 이내):');
  for (const s of spots ?? []) {
    const pct = Math.round((s.exit_frac as number) * 100);
    console.log(`  ${String(pct).padStart(3)}%  ${s.detour_min}분  ${s.trust_score}점  [${s.type}] ${s.name}`);
  }
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

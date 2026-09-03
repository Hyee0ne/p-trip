-- `discover_ahead` 의 쓰임새가 바뀌었다 — 동승자 모드(DR-05)가 사라지고
-- **레이더(DR-01/02)가 유일한 호출자**가 됐다 (2026-09-03).
--
-- 본문은 그대로다. 주석만 사실에 맞춘다 — 거짓말하는 주석은 없느니만 못하다.
--
-- ⚠ 신뢰도 게이트와 우회 제한은 **여기가 아니라 호출부**가 건다.
--   레이더는 `spot_cards` 를 다시 조회하면서 trust_score ≥ 60, detour_min ≤ 10 을 건다.
--   이 함수는 '현 위치에서 진행 방향 반경 안'만 답한다.
--
-- ⚠ **경로가 아니라 현재 위치 기준이다** (원칙 2). 코스를 벗어나도 그대로 돈다.
create or replace function public.discover_ahead(
  p_lat double precision,
  p_lng double precision,
  p_heading double precision default null,   -- 없으면 전방향
  p_km double precision default 5,           -- 레이더 반경. 동승자 시절 기본값 20에서 내렸다
  p_deg double precision default 60
)
returns table (id uuid, distance_km double precision)
language sql stable as $$
  with me as (
    select extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng, p_lat), 4326) as g
  )
  select
    s.id,
    round((extensions.ST_Distance(s.geom::extensions.geography, me.g::extensions.geography)
           / 1000.0)::numeric, 1)::double precision as distance_km
  from public.spots s, me
  where extensions.ST_DWithin(s.geom::extensions.geography, me.g::extensions.geography, p_km * 1000)
    -- 같은 자리(거리 0)면 방위가 정의되지 않는다. 그건 통과시킨다.
    and (
      p_heading is null
      or extensions.ST_Distance(s.geom, me.g) = 0
      or abs(
           ((degrees(extensions.ST_Azimuth(me.g, s.geom)) - p_heading + 540)::numeric % 360) - 180
         ) <= p_deg
    )
  order by distance_km
  limit 40;
$$;

grant execute on function public.discover_ahead(double precision, double precision, double precision, double precision, double precision)
  to anon, authenticated, service_role;

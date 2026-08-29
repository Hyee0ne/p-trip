-- DR-05 동승자 모드 조회.
--
-- ⚠ DR-01(레이더 카드)과 조건이 다르다:
--   · 반경이 넓다 (기본 20km) — 동승자는 미리 훑는다
--   · **신뢰도 게이트를 걸지 않는다** — 얕은 데이터는 알림엔 안 태우되 브라우징엔 보여준다
--     (§4-5). 운전자를 방해하지 않는 화면이라 기준이 다르다.
--   · 진행 방향 ±60°만 — 이미 지나친 곳을 동승자에게 보여줄 이유가 없다
--
-- ⚠ **경로가 아니라 현재 위치 기준이다** (원칙 2). 코스를 벗어나도 그대로 돈다.
create or replace function public.discover_ahead(
  p_lat double precision,
  p_lng double precision,
  p_heading double precision default null,   -- 없으면 전방향
  p_km double precision default 20,
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

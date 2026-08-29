-- 앱이 읽는 뷰·함수. 화면이 계산할 것을 줄이고, 날짜에 따라 달라지는 판정은 DB가 맡는다.

-- ── 스팟 카드 ────────────────────────────────────────────
-- ⚠ 별점·후기·랭킹 컬럼은 없다 (원칙 3). 정렬은 호출부가 신뢰도·거리로만 한다.
create or replace view public.spot_cards
with (security_invoker = true) as
select
  s.id, s.name, s.type, s.route_id, s.detour_min, s.trust_score,
  s.lat, s.lng, s.addr, s.tel, s.open_hours, s.image_url, s.overview, s.exit_frac,
  -- 한 줄 소개 = 개요 앞부분. 개요가 없으면 빈 문자열 — 지어내지 않는다.
  coalesce(left(regexp_replace(s.overview, '\s+', ' ', 'g'), 45), '') as blurb,
  (m.spot_id is not null)                              as is_market,
  m.open_cycle,
  public.is_market_day(m.open_cycle, current_date)     as market_today,
  -- 다음 장날까지 며칠 (오늘이 장날이면 0). 끝자리 규칙이라 최대 10일 안에 반드시 나온다.
  (select min(d) from generate_series(0, 10) d
    where public.is_market_day(m.open_cycle, current_date + d)) as market_in_days,
  (select min(e.end_date) from public.events e
    where e.spot_id = s.id and e.end_date >= current_date)      as event_end,
  r.name as route_name
from public.spots s
left join public.markets m on m.spot_id = s.id
left join public.routes  r on r.id = s.route_id;

grant select on public.spot_cards to anon, authenticated, service_role;

-- ── 현 위치에서 탈 수 있는 노선 (CO-07) ──────────────────
-- 선형은 **화면 주변만 잘라서** 준다. 전국 선형을 통째로 내려보내면 수 MB가 된다.
create or replace function public.nearby_routes(
  p_lat double precision,
  p_lng double precision,
  p_max_km double precision default 30,
  p_clip_deg double precision default 0.6
)
returns table (
  id int, name text, axis text, drivable boolean, from_to text,
  total_km numeric, distance_km double precision, geojson text
) language sql stable as $$
  select
    r.id, r.name, r.axis, r.drivable, r.from_to, r.total_km,
    round((extensions.ST_Distance(
      r.geom::extensions.geography,
      extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng, p_lat), 4326)::extensions.geography
    ) / 1000.0)::numeric, 1)::double precision as distance_km,
    extensions.ST_AsGeoJSON(
      extensions.ST_Intersection(
        r.geom,
        extensions.ST_MakeEnvelope(
          p_lng - p_clip_deg, p_lat - p_clip_deg,
          p_lng + p_clip_deg, p_lat + p_clip_deg, 4326)
      )
    ) as geojson
  from public.routes r
  where r.geom is not null
    and extensions.ST_DWithin(
          r.geom::extensions.geography,
          extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng, p_lat), 4326)::extensions.geography,
          p_max_km * 1000)
  order by distance_km;
$$;

grant execute on function public.nearby_routes(double precision, double precision, double precision, double precision)
  to anon, authenticated, service_role;

-- ── 오늘 이 격자의 해·달 ─────────────────────────────────
create or replace function public.sun_moon_today(p_lat double precision, p_lng double precision)
returns setof public.sun_moon language sql stable as $$
  select * from public.sun_moon
  where locdate = current_date
    and grid_lat = round(p_lat::numeric, 1)
    and grid_lng = round(p_lng::numeric, 1)
  limit 1;
$$;

grant execute on function public.sun_moon_today(double precision, double precision)
  to anon, authenticated, service_role;

-- ── 오늘의 천문현상 (§3.8) ───────────────────────────────
create or replace function public.astro_today(p_days int default 1)
returns setof public.astro_events language sql stable as $$
  select * from public.astro_events
  where is_event and locdate between current_date and current_date + p_days
  order by locdate;
$$;

grant execute on function public.astro_today(int) to anon, authenticated, service_role;

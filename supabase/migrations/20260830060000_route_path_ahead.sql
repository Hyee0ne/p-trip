-- 지금 여기서 이 국도를 타고 **고른 방향으로** 갈 선형을 잘라준다 (CO-08 길 떠나기).
--
-- 코스 없이 국도만 고르고 출발하는 흐름이 생기면서 필요해졌다.
-- 앱은 코스 선형(courses.geom) 대신 이걸 받아 달린다.
--
-- ⚠ 길안내가 아니다 (원칙 1). "어디로 가라"가 아니라 **"이 길이 이쪽으로 이렇게 뻗어 있다"**를
--    돌려줄 뿐이다. 벗어나도 아무 일도 일어나지 않고, 재탐색하지 않는다.
-- ⚠ routes.geom은 MultiLineString이다. ST_LineLocatePoint는 LineString만 받아서
--    ST_LineMerge로 이은 뒤, **사용자와 가장 가까운 조각**을 쓴다.
--    조각들이 실제로 안 이어져 있으면 그 조각 끝에서 선형이 끝난다 — 억지로 잇지 않는다.
create or replace function public.route_path_ahead(
  p_route_id int,
  p_lat double precision,
  p_lng double precision,
  p_north_or_east boolean,
  p_max_km double precision default 120
) returns table (geojson text, km double precision)
language sql stable
set search_path = public, extensions
as $$
  with pt as (
    select extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng, p_lat), 4326) as g
  ),
  parts as (
    -- 이을 수 있는 만큼 잇고, 조각별로 나눈다.
    select (extensions.ST_Dump(extensions.ST_LineMerge(r.geom))).geom as g, r.axis
    from public.routes r
    where r.id = p_route_id and r.geom is not null
  ),
  nearest as (
    select p.g, p.axis
    from parts p, pt
    order by p.g <-> pt.g
    limit 1
  ),
  m as (
    select
      n.g,
      n.axis,
      extensions.ST_Length(n.g::extensions.geography) / 1000.0 as total_km,
      extensions.ST_LineLocatePoint(n.g, pt.g) as frac,
      -- 이 조각은 진행할수록 북쪽(또는 동쪽)으로 가는가.
      case
        when n.axis = 'EW' then
          extensions.ST_X(extensions.ST_EndPoint(n.g)) > extensions.ST_X(extensions.ST_StartPoint(n.g))
        else
          extensions.ST_Y(extensions.ST_EndPoint(n.g)) > extensions.ST_Y(extensions.ST_StartPoint(n.g))
      end as forward_is_north_or_east
    from nearest n, pt
  ),
  cut as (
    select
      case
        -- 고른 방향이 선형 진행 방향과 같으면 앞으로, 아니면 뒤로 자르고 뒤집는다.
        when m.forward_is_north_or_east = p_north_or_east then
          extensions.ST_LineSubstring(
            m.g, m.frac, least(1.0, m.frac + (p_max_km / greatest(m.total_km, 0.001)))
          )
        else
          extensions.ST_Reverse(
            extensions.ST_LineSubstring(
              m.g, greatest(0.0, m.frac - (p_max_km / greatest(m.total_km, 0.001))), m.frac
            )
          )
      end as g
    from m
  )
  select
    extensions.ST_AsGeoJSON(cut.g),
    extensions.ST_Length(cut.g::extensions.geography) / 1000.0
  from cut
  -- 점 하나짜리는 달릴 게 없다. 그때는 아무것도 안 돌려준다.
  where extensions.ST_NPoints(cut.g) >= 2;
$$;

comment on function public.route_path_ahead(int, double precision, double precision, boolean, double precision) is
  '지금 위치에서 이 국도를 타고 고른 방향으로 뻗은 선형. CO-08이 쓴다.
   ⚠ 길안내가 아니다 — 이 길이 이쪽으로 이렇게 뻗어 있다는 사실만 돌려준다.';

grant execute on function public.route_path_ahead(int, double precision, double precision, boolean, double precision)
  to anon, authenticated, service_role;

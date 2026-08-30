-- 후보 좌표 중 **국도 회랑 안에 있는 것**만 골라낸다 (파이프라인 전국화).
--
-- 그전에는 파이프라인이 7번 국도 해안선을 **손으로 찍은 좌표 배열**로 들고 있었다.
-- 전국 51선에 그 방식을 쓸 수는 없다 — 이미 `routes.geom`에 실제 선형이 있다.
--
-- 왜 목록 조회 직후에 거르는가: 스팟 상세는 **1건당 1콜**이다. 회랑 밖 스팟까지
-- 상세를 받으면 할당량이 몇 배로 든다. 좌표만 먼저 던져 걸러내고 살아남은 것만 받는다.
--
-- ⚠ 인덱스를 타게 도 좌표로 먼저 거른다 (match_route_km과 같은 함정).
-- ⚠ 연산자가 extensions 스키마에 있어 search_path가 필요하다.
create or replace function public.near_routes(p_points jsonb, p_max_km double precision default 10)
returns table (idx int, route_id int, distance_km double precision)
language sql stable
set search_path = public, extensions
as $$
  with pts as (
    select
      (ordinality - 1)::int as idx,
      extensions.ST_SetSRID(
        extensions.ST_MakePoint((e->>1)::float8, (e->>0)::float8), 4326
      ) as p
    from jsonb_array_elements(p_points) with ordinality as t(e, ordinality)
  )
  select
    pts.idx,
    m.id,
    m.km
  from pts
  join lateral (
    select
      r.id,
      extensions.ST_Distance(
        r.geom::extensions.geography, pts.p::extensions.geography
      ) / 1000.0 as km
    from public.routes r
    where r.geom is not null
      -- 도 단위 사각형으로 먼저 자른다. 위도 1도 ≈ 111km라 여유를 둔다.
      and r.geom && extensions.ST_Expand(pts.p, p_max_km / 88.0)
      and extensions.ST_DWithin(
        r.geom::extensions.geography, pts.p::extensions.geography, p_max_km * 1000
      )
    order by r.geom <-> pts.p
    limit 1
  ) m on true;
$$;

comment on function public.near_routes(jsonb, double precision) is
  '후보 좌표([위도,경도] 배열의 배열) 중 국도 회랑 안의 것만 인덱스와 함께 돌려준다.
   ⚠ 상세 조회 전에 거르는 용도다 — 상세는 1건당 1콜이라 회랑 밖까지 받으면 할당량이 몇 배가 된다.';

grant execute on function public.near_routes(jsonb, double precision)
  to anon, authenticated, service_role;

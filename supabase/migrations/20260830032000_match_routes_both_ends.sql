-- match_route_km 정확성 수정.
--
-- ⚠ 시작점만 보고 구간을 붙이면 **국도를 벗어난 구간까지 적립된다.**
--    검증에서 드러났다: 코스 위 점들 뒤에 바다 좌표를 붙였더니 65km 코스가 78km로 늘었다.
--    마지막 코스 점이 7번에 붙어 있으니, 거기서 바다까지의 50km 점프가 통째로 7번이 됐다.
--
-- 바른 규칙: **양 끝이 같은 노선에 붙을 때만** 그 구간을 센다.
-- 벗어났다 돌아온 구간은 아무 데도 안 넣는다 — 안 달린 길을 색칠하지 않는다.
--
-- ⚠ 길이 상한도 둔다. 터널·앱 종료로 로그가 끊기면 두 점 사이가 수십 km가 되는데,
--    양 끝이 다 7번 위여도 그 사이를 달렸다고 단정할 수 없다.
--    정상 간격은 0.5km 또는 2분이라 5km면 넉넉하다.
create or replace function public.match_route_km(p_points jsonb)
returns table (route_id int, km double precision)
language sql stable
set search_path = public, extensions
as $$
  with pts as (
    select
      ordinality as i,
      extensions.ST_SetSRID(
        extensions.ST_MakePoint((e->>1)::float8, (e->>0)::float8), 4326
      ) as p
    from jsonb_array_elements(p_points) with ordinality as t(e, ordinality)
  ),
  snapped as (
    select
      pts.i,
      pts.p,
      (
        select r.id
        from public.routes r
        where r.geom is not null
          and r.geom && extensions.ST_Expand(pts.p, 0.001)
          and extensions.ST_DWithin(r.geom::extensions.geography, pts.p::extensions.geography, 50)
        order by r.geom <-> pts.p
        limit 1
      ) as route_id
    from pts
  ),
  segs as (
    select
      a.route_id,
      extensions.ST_Distance(
        a.p::extensions.geography, b.p::extensions.geography
      ) / 1000.0 as seg_km
    from snapped a
    join snapped b on b.i = a.i + 1
    -- 양 끝이 같은 노선일 때만.
    where a.route_id is not null and a.route_id = b.route_id
  )
  select route_id, sum(seg_km)
  from segs
  where seg_km <= 5
  group by route_id
  order by route_id;
$$;

comment on function public.match_route_km(jsonb) is
  '지나온 점들 → 노선별 km. 점은 [위도, 경도] 배열의 배열.
   ⚠ 양 끝이 같은 노선에 50m 안으로 붙는 구간만 센다. 벗어난 구간은 버린다 —
     안 달린 길을 색칠하지 않는다.
   ⚠ 이건 길안내가 아니다. 지나온 뒤 어디였는지 셀 뿐이다.';

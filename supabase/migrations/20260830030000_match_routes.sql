-- 맵매칭: 지나온 GPS 점들을 노선에 붙여 **노선별 주행 km**를 낸다.
--
-- 왜 필요한가: 여행 1건을 노선 1개에 통째로 귀속하면, 한 여행에서 7번 국도를 달리다
-- 35번으로 갈아탄 경우 65km 전부가 7번에 적립되고 35번은 영영 안 색칠된다.
-- '국도 51선 수집'이 이 앱의 게임화 축인데 숫자가 틀리게 된다.
--
-- ⚠ 이건 **길안내가 아니다** (원칙 1). 지나온 뒤 어디였는지 세는 것뿐이고,
--    어디로 가라거나 경로를 벗어났다는 말을 만들지 않는다.
-- ⚠ 50m 안에 노선이 없으면 그 구간은 **아무 데도 안 넣는다.** 국도가 아닌 길을 달린 것이다 —
--    가장 가까운 노선에 억지로 붙이면 안 달린 길이 색칠된다.
create or replace function public.match_route_km(p_points jsonb)
returns table (route_id int, km double precision)
language sql stable as $$
  with pts as (
    select
      ordinality as i,
      extensions.ST_SetSRID(
        extensions.ST_MakePoint((e->>1)::float8, (e->>0)::float8), 4326
      )::extensions.geography as g
    from jsonb_array_elements(p_points) with ordinality as t(e, ordinality)
  ),
  segs as (
    -- 구간은 **시작점이 있던 노선**에 넣는다. 0.5km 간격이라 중점을 쓰면
    -- 굽은 길에서 도로 밖으로 떨어져 구간이 통째로 버려진다.
    select
      extensions.ST_Distance(a.g, b.g) / 1000.0 as seg_km,
      (
        select r.id from public.routes r
        where r.geom is not null
          and extensions.ST_DWithin(r.geom::extensions.geography, a.g, 50)
        order by extensions.ST_Distance(r.geom::extensions.geography, a.g)
        limit 1
      ) as matched
    from pts a join pts b on b.i = a.i + 1
  )
  select matched, sum(seg_km)
  from segs
  where matched is not null
  group by matched
  order by matched;
$$;

comment on function public.match_route_km(jsonb) is
  '지나온 점들 → 노선별 km. 점은 [위도, 경도] 배열의 배열. 50m 안에 노선이 없으면 버린다.';

grant execute on function public.match_route_km(jsonb) to anon, authenticated, service_role;

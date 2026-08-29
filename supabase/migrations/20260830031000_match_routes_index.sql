-- match_route_km 성능 수정.
--
-- ⚠ `r.geom::geography`로 캐스팅하면 **GiST 인덱스를 못 쓴다.** 인덱스는 4326 도(degree)
--    좌표의 geom에 걸려 있는데 캐스팅하면 다른 타입이 되어 51개 노선 18만 점을 전부 훑는다.
--    점 20개짜리 경로가 statement timeout에 걸렸다 (compute_spot_exits 때와 같은 함정).
--
-- 바른 방법: **도 좌표로 먼저 거른 뒤**(&& 연산자 — 인덱스를 탄다) 남은 것만 geography로
-- 정확히 잰다. ST_Expand 0.001도는 위도 111m·경도 88m라 50m 판정을 놓치지 않는다.
create or replace function public.match_route_km(p_points jsonb)
returns table (route_id int, km double precision)
-- ⚠ PostGIS가 extensions 스키마에 있어 `&&`·`<->` **연산자**가 기본 경로에 없다.
--    함수 호출은 extensions.ST_*로 적을 수 있지만 연산자는 안 된다 — search_path로 넣는다.
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
  segs as (
    -- 구간은 **시작점이 있던 노선**에 넣는다. 0.5km 간격이라 중점을 쓰면
    -- 굽은 길에서 도로 밖으로 떨어져 구간이 통째로 버려진다.
    select
      a.p as ap,
      extensions.ST_Distance(
        a.p::extensions.geography, b.p::extensions.geography
      ) / 1000.0 as seg_km
    from pts a join pts b on b.i = a.i + 1
  ),
  matched as (
    select s.seg_km, m.id as route_id
    from segs s
    left join lateral (
      select r.id
      from public.routes r
      where r.geom is not null
        and r.geom && extensions.ST_Expand(s.ap, 0.001)
        and extensions.ST_DWithin(r.geom::extensions.geography, s.ap::extensions.geography, 50)
      order by r.geom <-> s.ap
      limit 1
    ) m on true
  )
  select route_id, sum(seg_km)
  from matched
  where route_id is not null
  group by route_id
  order by route_id;
$$;

comment on function public.match_route_km(jsonb) is
  '지나온 점들 → 노선별 km. 점은 [위도, 경도] 배열의 배열.
   ⚠ 50m 안에 노선이 없으면 버린다 — 국도가 아닌 길을 억지로 색칠하지 않는다.
   ⚠ 이건 길안내가 아니다. 지나온 뒤 어디였는지 셀 뿐이다.';

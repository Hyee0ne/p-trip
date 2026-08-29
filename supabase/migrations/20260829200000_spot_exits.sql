-- 국도 진출점 계산 (TECH_SPEC §3.1).
--
-- ⚠ **라우팅 API를 쓰지 않는다** (원칙 1 비내비). 노선 형상과 직선거리만으로 낸다.
--   detour_min은 '국도에서 약 N분'이라는 어림이지 실측 소요시간이 아니고,
--   UI에서 도착 시각으로 환산하지 않는다.
create or replace function public.compute_spot_exits(max_km double precision default 20)
returns table (updated int, matched int) language plpgsql as $$
declare
  n int := 0;
begin
  with nearest as (
    select
      s.id as spot_id,
      r.id as route_id,
      extensions.ST_ClosestPoint(r.geom, s.geom) as exit_geom,
      extensions.ST_Distance(
        extensions.ST_ClosestPoint(r.geom, s.geom)::extensions.geography,
        s.geom::extensions.geography
      ) as exit_m
    from public.spots s
    cross join lateral (
      select r2.id, r2.geom
      from public.routes r2
      where r2.geom is not null
        -- 먼저 대충 걸러야 51개 전국 노선을 매번 다 재지 않는다.
        and extensions.ST_DWithin(r2.geom::extensions.geography, s.geom::extensions.geography, max_km * 1000)
      order by r2.geom <-> s.geom
      limit 1
    ) r
  )
  update public.spots s
  set route_id  = n.route_id,
      exit_geom = n.exit_geom,
      -- 지방도 40km/h 가정, **왕복**. 올림해서 분 단위.
      detour_min = ceil(n.exit_m / 1000.0 / 40.0 * 60.0)::int * 2
  from nearest n
  where s.id = n.spot_id;

  get diagnostics n = row_count;
  return query select n, (select count(*)::int from public.spots where route_id is not null);
end;
$$;

comment on function public.compute_spot_exits(double precision) is
  '스팟마다 가장 가까운 국도와 진출점·우회시간을 채운다.
   ⚠ exit_frac은 여기서 안 낸다 — routes.geom이 MultiLineString이라
   ST_LineLocatePoint를 못 쓴다. 코스(courses.geom)가 생기면 그걸 기준으로 낸다.';

create index if not exists spots_detour_idx on public.spots (route_id, detour_min);

grant execute on function public.compute_spot_exits(double precision) to service_role;

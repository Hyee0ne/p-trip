-- ⚠ routes.geom에 공간 인덱스를 안 걸어뒀다. 51개 노선에 점이 18만 개라
--   ST_DWithin이 매번 전부 훑어서 진출점 계산이 statement timeout으로 죽었다.
create index if not exists routes_geom_idx on public.routes using gist (geom);

-- 배치로 나눠 돈다. 한 번에 625건을 다 처리하면 여전히 시간이 넘칠 수 있다.
-- 이미 채운 스팟은 건너뛰므로 여러 번 불러 이어서 끝낸다.
create or replace function public.compute_spot_exits(
  batch int default 200,
  max_km double precision default 20
)
returns table (updated int, remaining int) language plpgsql as $$
declare
  n int := 0;
begin
  with todo as (
    select id, geom from public.spots
    where route_id is null or detour_min is null
    limit batch
  ),
  nearest as (
    select
      t.id as spot_id,
      r.id as route_id,
      extensions.ST_ClosestPoint(r.geom, t.geom) as exit_geom,
      extensions.ST_Distance(
        extensions.ST_ClosestPoint(r.geom, t.geom)::extensions.geography,
        t.geom::extensions.geography
      ) as exit_m
    from todo t
    cross join lateral (
      select r2.id, r2.geom
      from public.routes r2
      where r2.geom is not null
        and extensions.ST_DWithin(
              r2.geom::extensions.geography, t.geom::extensions.geography, max_km * 1000)
      order by r2.geom <-> t.geom
      limit 1
    ) r
  )
  update public.spots s
  set route_id  = n.route_id,
      exit_geom = n.exit_geom,
      detour_min = ceil(n.exit_m / 1000.0 / 40.0 * 60.0)::int * 2
  from nearest n
  where s.id = n.spot_id;

  get diagnostics n = row_count;
  return query
    select n, (select count(*)::int from public.spots where route_id is null or detour_min is null);
end;
$$;

grant execute on function public.compute_spot_exits(int, double precision) to service_role;
drop function if exists public.compute_spot_exits(double precision);

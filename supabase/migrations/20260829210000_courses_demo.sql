-- 코스 = 노선의 **큐레이션** 구간 (TECH_SPEC §2).
--
-- ⚠ 노선을 기계적으로 N등분해 코스를 찍어내지 않는다. 그러면 '큐레이션'이 아니라 토막이다.
--   데모 구간(7번 국도 삼척–강릉) 하나를 제대로 만들고, 나머지는 사람이 정할 때 늘린다.
--   코스가 없는 노선은 앱에서 "이 길의 코스를 준비하고 있어요"로 뜬다 — 그게 사실이다.

alter table public.courses add column if not exists blurb text not null default '';
comment on column public.courses.blurb is '카드 아래 한 줄. 기획 카피를 그대로 쓴다.';

/**
 * 노선 일부를 잘라 코스를 만든다.
 * routes.geom은 MultiLineString이라 bbox로 자른 뒤 가장 긴 갈래 하나를 코스 선형으로 삼는다.
 * ⚠ courses.geom은 LineString이어야 한다 — exit_frac(ST_LineLocatePoint)이 그걸 요구한다.
 */
create or replace function public.upsert_course_from_route(
  p_id uuid,
  p_route_id int,
  p_title text,
  p_start text,
  p_end text,
  p_blurb text,
  p_min_lat double precision, p_max_lat double precision,
  p_min_lng double precision, p_max_lng double precision,
  p_kmh double precision default 45          -- 국도 실효 주행속도 가정
) returns table (course_id uuid, km numeric, minutes int, points int)
language plpgsql as $$
declare
  line extensions.geometry;
  dist_km numeric;
  n int;
begin
  select extensions.ST_GeometryN(clipped, idx) into line
  from (
    select g.clipped,
           (select i from generate_series(1, extensions.ST_NumGeometries(g.clipped)) i
             order by extensions.ST_Length(extensions.ST_GeometryN(g.clipped, i)::extensions.geography) desc
             limit 1) as idx
    from (
      select extensions.ST_LineMerge(
               extensions.ST_Intersection(
                 r.geom,
                 extensions.ST_MakeEnvelope(p_min_lng, p_min_lat, p_max_lng, p_max_lat, 4326)
               )
             ) as clipped
      from public.routes r where r.id = p_route_id
    ) g
  ) x;

  if line is null or extensions.ST_NumPoints(line) < 2 then
    raise exception '노선 %번을 그 범위로 잘랐더니 선이 안 나왔다. 좌표 범위를 확인할 것.', p_route_id;
  end if;

  dist_km := round((extensions.ST_Length(line::extensions.geography) / 1000.0)::numeric, 1);
  n := extensions.ST_NumPoints(line);

  insert into public.courses (id, route_id, title, start_name, end_name, blurb,
                              distance_km, duration_min, geom, is_demo)
  values (p_id, p_route_id, p_title, p_start, p_end, p_blurb,
          dist_km, ceil(dist_km / p_kmh * 60)::int, line, true)
  on conflict (id) do update set
    route_id = excluded.route_id, title = excluded.title,
    start_name = excluded.start_name, end_name = excluded.end_name,
    blurb = excluded.blurb, distance_km = excluded.distance_km,
    duration_min = excluded.duration_min, geom = excluded.geom, is_demo = true;

  return query select p_id, dist_km, ceil(dist_km / p_kmh * 60)::int, n;
end;
$$;

/**
 * 코스 위 스팟의 exit_frac을 채운다.
 * 노선 전체가 아니라 **코스** 기준이다 — 진출로 역산(§3.1)이 코스를 달리는 중에 쓰이기 때문이다.
 */
create or replace function public.compute_exit_frac(p_course_id uuid, p_within_km double precision default 5)
returns table (updated int) language plpgsql as $$
declare n int := 0;
begin
  with c as (select geom from public.courses where id = p_course_id)
  update public.spots s
  set exit_frac = extensions.ST_LineLocatePoint(c.geom, s.geom)
  from c
  where extensions.ST_DWithin(c.geom::extensions.geography, s.geom::extensions.geography, p_within_km * 1000);
  get diagnostics n = row_count;
  return query select n;
end;
$$;

grant execute on function public.upsert_course_from_route(uuid,int,text,text,text,text,double precision,double precision,double precision,double precision,double precision) to service_role;
grant execute on function public.compute_exit_frac(uuid, double precision) to service_role;

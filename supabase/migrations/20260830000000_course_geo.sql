-- 코스 선형을 앱에 준다. mock 주행이 이 선을 따라 달린다.
-- ⚠ 이건 **길안내용이 아니다.** 우리가 그리는 건 "어디를 지나는가"이지 "어떻게 가는가"가 아니다
--   (원칙 1). 턴바이턴·재탐색은 여전히 만들지 않는다.
create or replace function public.course_geojson(p_id uuid)
returns table (id uuid, title text, distance_km numeric, duration_min int, geojson text)
language sql stable as $$
  select c.id, c.title, c.distance_km, c.duration_min,
         extensions.ST_AsGeoJSON(c.geom) as geojson
  from public.courses c
  where c.id = p_id;
$$;

grant execute on function public.course_geojson(uuid) to anon, authenticated, service_role;

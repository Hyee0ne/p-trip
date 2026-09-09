-- ── 51선 전국 선형 (CO-07 지도) — 단순화해서 한 번에 ─────────────────────
-- nearby_routes 는 화면 주변(30km)만 잘라 준다. 지도엔 51선이 **다** 그려져야 한다 —
-- 실기기에서 43번 국도 근처에 서니 파란 선이 그것 하나뿐이었다 (2026-09-09).
-- ST_SimplifyPreserveTopology 0.002° (~200m) + 소수 5자리(~1m) 면 전국이 수백 KB 다.
-- ⚠ 좌표를 받지 않는다 — 위치와 무관한 조회라 위치정보 문의의 표에 오를 일이 없다.
create or replace function public.route_lines_all(p_tol double precision default 0.002)
returns table (
  id int, name text, axis text, drivable boolean, from_to text, total_km numeric, geojson text
) language sql stable as $$
  select
    r.id, r.name, r.axis, r.drivable, r.from_to, r.total_km,
    extensions.ST_AsGeoJSON(extensions.ST_SimplifyPreserveTopology(r.geom, p_tol), 5) as geojson
  from public.routes r
  where r.geom is not null
  order by r.id;
$$;

grant execute on function public.route_lines_all(double precision) to anon, authenticated, service_role;

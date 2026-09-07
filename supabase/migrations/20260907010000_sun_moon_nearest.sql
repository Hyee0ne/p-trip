-- 오늘 이 근처의 해·달 — **가장 가까운 격자**로 바꾼다 (2026-09-07).
--
-- ⚠ 전에는 격자가 **정확히 일치**해야 했다 (`grid_lat = round(p_lat, 1)`).
--   0.1도는 약 11km인데 레이더 반경은 5km다 — 운전자가 전망 스팟의 **옆 칸**에 있으면
--   일몰 시각을 못 찾아 카드가 통째로 안 떴다. 조용히 null 이라 아무도 몰랐다.
--
-- ⚠ 같은 날, 일몰 격자를 **전망 스팟이 있는 칸만** 채우도록 바꿨다 (`fetch:sunset`).
--   107칸 → 34칸. 성기게 채우는 대신 가장 가까운 칸을 쓴다.
--   일몰 시각은 경도 0.1도당 1분이 안 되게 움직인다 — 40km 안이면 3분 안쪽이고,
--   카드가 뜨는 창이 일몰 −60~−20분이라 아무 차이가 없다.
--
-- ⚠ 여전히 읽기 전용(stable)이다. 좌표를 받아 조회만 하고 아무것도 남기지 않는다.
create or replace function public.sun_moon_today(p_lat double precision, p_lng double precision)
returns setof public.sun_moon language sql stable as $$
  select * from public.sun_moon
  where locdate = current_date
    -- 먼저 사각형으로 좁혀 기본키 인덱스를 쓴다. 0.4도 ≈ 44km.
    and grid_lat between (p_lat - 0.4)::numeric and (p_lat + 0.4)::numeric
    and grid_lng between (p_lng - 0.5)::numeric and (p_lng + 0.5)::numeric
  -- 위도 1도 ≈ 111km, 경도 1도 ≈ 88km (북위 37도). 제곱거리로 비교한다.
  order by
    power((grid_lat - p_lat::numeric) * 111, 2) + power((grid_lng - p_lng::numeric) * 88, 2)
  limit 1;
$$;

comment on function public.sun_moon_today(double precision, double precision) is
  '오늘 이 근처의 일몰. 가장 가까운 격자(≤약 44km)를 돌려준다.
   ⚠ 격자는 전망 스팟이 있는 칸만 채운다 — 성긴 대신 최근접으로 찾는다.';

grant execute on function public.sun_moon_today(double precision, double precision)
  to anon, authenticated, service_role;

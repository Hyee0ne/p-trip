-- 그날 밤 하늘 (SCREENS.md MY-02 §3, TECH_SPEC §3.8).
--
-- sun_moon_today/astro_today는 **오늘**만 본다. 여행기는 지난 날을 돌아보는 화면이라
-- 그날 날짜로 물어야 한다.
--
-- ⚠ 반환은 '계산된 사실'만이다. 점수·등급·순위를 내보내지 않는다 (원칙 3).
-- ⚠ moonset은 **그날 아침에 진 달**이라 moonrise와 짝이 아니다 (20260829190000 참고).
--    그래서 '달이 몇 시에 졌다'를 돌려주지 않는다 — 틀린 문장이 된다.
--    호출부가 쓸 수 있는 건 moonless_after_dusk의 판정뿐이다.
create or replace function public.night_sky_on(
  p_lat double precision, p_lng double precision, p_date date
) returns table (moonless boolean, event_title text)
language sql stable as $$
  select
    (select public.moonless_after_dusk(sm.astro_dusk, sm.moonrise, sm.moonset)
       from public.sun_moon sm
      where sm.locdate = p_date
        and sm.grid_lat = round(p_lat::numeric, 1)
        and sm.grid_lng = round(p_lng::numeric, 1)
      limit 1),
    (select ae.title
       from public.astro_events ae
      where ae.is_event and ae.locdate = p_date
      order by ae.event_time nulls last
      limit 1);
$$;

comment on function public.night_sky_on(double precision, double precision, date) is
  '그날 밤의 사실 한 줄용. 데이터가 없으면 둘 다 null — 호출부는 줄을 그리지 않는다.';

grant execute on function public.night_sky_on(double precision, double precision, date)
  to anon, authenticated, service_role;

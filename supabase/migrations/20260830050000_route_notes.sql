-- 노선 한 줄 (CO-01 재설계 — 길을 먼저, 정보는 가면서).
--
-- 큐레이션을 홈의 섹션·카드로 따로 세우지 않고 **길에 붙인다.**
-- 목록이 아니라 길의 속성이라, 떠날 이유는 남으면서 무엇이 있는지는 안 밝힌다.
--
-- ⚠ **절대량 인기로 정렬하지 않는다** (원칙 3). "제일 많이 다니는 길"은 만들지 않는다.
--    변화율(연관관광지 2시점에서 순위가 오른 것)과 시의성(오늘 장날)만 쓴다.
--    그래야 뻔한 유명 국도가 아니라 **조용히 뜨는 길**이 올라온다.
-- ⚠ 근거가 없으면 **줄을 만들지 않는다.** 채우려고 지어내지 않는다.
create or replace function public.route_notes()
returns table (route_id int, kind text, spots int)
language sql stable
set search_path = public, extensions
as $$
  with market as (
    -- 오늘 장이 서는 곳이 있는 노선.
    select s.route_id, count(*)::int as n
    from public.spot_cards s
    where s.market_today and s.route_id is not null
    group by s.route_id
  ),
  rising as (
    -- 요즘 사람들이 더 도는 곳이 있는 노선 (연관관광지 2시점 · 순위 상승).
    select s.route_id, count(*)::int as n
    from public.rising_spots(200) r
    join public.spots s on s.id = r.spot_id
    where s.route_id is not null
    group by s.route_id
  )
  -- 한 노선에 둘 다 있으면 **장날이 이긴다.** 오늘만 있는 일이 더 급하다.
  select m.route_id, 'market_today'::text, m.n from market m
  union all
  select g.route_id, 'rising'::text, g.n
  from rising g
  where not exists (select 1 from market m where m.route_id = g.route_id);
$$;

comment on function public.route_notes() is
  '노선별 한 줄의 근거. 오늘 장날 > 요즘 더 도는 길. 근거 없는 노선은 아예 안 나온다.
   ⚠ 절대량 인기 정렬 금지 (원칙 3) — 변화율과 시의성만 쓴다.';

grant execute on function public.route_notes() to anon, authenticated, service_role;

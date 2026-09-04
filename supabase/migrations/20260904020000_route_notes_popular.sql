-- 노선 한 줄에 `popular` 를 더한다 (2026-09-04).
--
-- `rising_spots` 가 변화(jump > 0)와 절대 순위(jump = 0)를 함께 돌려주게 되면서,
-- 둘을 한 문구로 말하면 거짓말이 된다 — 절대 순위로 뽑힌 길은 '요즘 더' 도는 게 아니다.
--
-- ⚠ 한 노선에 변화가 하나라도 있으면 **rising 이 이긴다.** 관찰한 사실이 더 강하다.
-- ⚠ 우선순위: 오늘 장날 > 요즘 더 도는 길 > 다녀간 사람이 많은 길.
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
  linked as (
    select r.jump, s.route_id
    from public.rising_spots(200) r
    join public.spots s on s.id = r.spot_id
    where s.route_id is not null
  ),
  rising as (
    -- 순위가 실제로 오른 곳이 있는 노선.
    select route_id, count(*)::int as n from linked where jump > 0 group by route_id
  ),
  popular as (
    -- 변화는 못 쟀지만 흔적이 많은 노선.
    select route_id, count(*)::int as n from linked where jump = 0 group by route_id
  )
  select m.route_id, 'market_today'::text, m.n from market m
  union all
  select g.route_id, 'rising'::text, g.n
  from rising g
  where not exists (select 1 from market m where m.route_id = g.route_id)
  union all
  select p.route_id, 'popular'::text, p.n
  from popular p
  where not exists (select 1 from market m where m.route_id = p.route_id)
    and not exists (select 1 from rising g where g.route_id = p.route_id);
$$;

comment on function public.route_notes() is
  '노선별 한 줄의 근거. 오늘 장날 > 요즘 더 도는 길 > 다녀간 사람이 많은 길.
   근거 없는 노선은 아예 안 나온다.
   ⚠ popular 는 이동 흔적(연관관광지)이지 별점이 아니다 (원칙 3).';

grant execute on function public.route_notes() to anon, authenticated, service_role;

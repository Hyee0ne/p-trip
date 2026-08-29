-- blurb를 45자에서 자르니 "동해는 원"처럼 문장이 중간에 끊겼다.
-- 뷰는 넉넉히 주고, 어디서 끊을지는 화면이 정한다 (카드 폭이 화면마다 다르다).
create or replace view public.spot_cards
with (security_invoker = true) as
select
  s.id, s.name, s.type, s.route_id, s.detour_min, s.trust_score,
  s.lat, s.lng, s.addr, s.tel, s.open_hours, s.image_url, s.overview, s.exit_frac,
  coalesce(left(regexp_replace(s.overview, '\s+', ' ', 'g'), 200), '') as blurb,
  (m.spot_id is not null)                              as is_market,
  m.open_cycle,
  public.is_market_day(m.open_cycle, current_date)     as market_today,
  (select min(d) from generate_series(0, 10) d
    where public.is_market_day(m.open_cycle, current_date + d)) as market_in_days,
  (select min(e.end_date) from public.events e
    where e.spot_id = s.id and e.end_date >= current_date)      as event_end,
  r.name as route_name
from public.spots s
left join public.markets m on m.spot_id = s.id
left join public.routes  r on r.id = s.route_id;

grant select on public.spot_cards to anon, authenticated, service_role;

-- TourAPI 사진의 저작권 유형 (공공누리).
--
-- 목록 응답의 `cpyrhtDivCd` 를 그대로 담는다:
--   Type1 = 제1유형 (출처표시)              — 변형 가능
--   Type3 = 제3유형 (출처표시 + 변경금지)   — **변형 불가**
--   null  = API가 안 준 것. 모르는 건 모른다고 둔다
--
-- ⚠ 지금 앱은 사진을 관광공사 서버에서 **원본 URL 그대로** 띄우고 크롭·필터를 걸지 않는다.
--   그래서 당장은 Type3도 문제가 없다. 이 컬럼이 필요해지는 건 **사진을 합성할 때**다 —
--   공유 카드에 사진을 얹거나 썸네일을 잘라 만들면 그때부터 제3유형은 못 쓴다.
--   그 판단을 하려면 값이 있어야 하고, 값은 **수집할 때** 같이 받아야 한다.
--   나중에 넣으려면 전국을 다시 받아야 한다 (2026-09-03).
alter table public.spots
  add column if not exists image_rights text
    check (image_rights in ('Type1', 'Type3'));

comment on column public.spots.image_rights is
  'TourAPI cpyrhtDivCd. Type3 = 변경금지 — 사진을 합성·크롭하지 말 것';

-- 뷰에도 실어 보낸다. 앱이 지금 쓰지는 않지만, 쓰려는 순간에 마이그레이션을
-- 또 만들지 않아도 되게 해둔다.
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
  r.name as route_name,
  -- ⚠ **맨 끝에 붙인다.** `create or replace view` 는 컬럼을 중간에 끼워넣지 못한다 —
  --   중간에 두면 뒤 컬럼을 "이름 바꾸려 한다"고 보고 거부한다 (42P16).
  s.image_rights
from public.spots s
left join public.markets m on m.spot_id = s.id
left join public.routes  r on r.id = s.route_id;

grant select on public.spot_cards to anon, authenticated, service_role;

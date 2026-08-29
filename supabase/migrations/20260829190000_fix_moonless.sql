-- moonless_after_dusk 수정.
--
-- 실데이터로 검증하니 틀렸다. 2026-08-29 동해: 천문박명 20:30, 월출 19:23, 월몰 06:39.
-- 달이 박명 **전에** 떠서 밤새 하늘에 있는데 true가 나왔다.
-- 원인: 응답의 moonset은 그날 아침에 진 달(어젯밤 달)이라 moonrise와 짝이 아니다.
--       'moonset < moonrise'를 '달이 이미 졌다'로 읽은 게 잘못이다 — 오히려 그 반대다.
--
-- 바른 규칙:
--   moonrise > astro_dusk           → 박명 때 달이 아직 안 떴다 → 어둡다
--   moonrise <= astro_dusk 이고
--     moonset > moonrise            → 같은 날 낮에 졌다 → 어둡다
--     moonset < moonrise            → 다음날 새벽에 진다 = 밤새 떠 있다 → 밝다
create or replace function public.moonless_after_dusk(
  astro_dusk time, moonrise time, moonset time
) returns boolean language sql immutable as $$
  select case
    -- 박명을 모르면 판단하지 않는다. false가 아니라 '모름'이라 호출부가 줄을 안 그린다.
    when astro_dusk is null then null
    -- 달이 아예 안 뜨는 날
    when moonrise is null and moonset is null then true
    when moonrise is null then true
    -- 박명 뒤에 뜬다 → 그전까지 어둡다
    when moonrise > astro_dusk then true
    -- 박명 전에 떴다. 같은 날 안에 졌으면 어둡고, 안 졌으면 밤새 밝다.
    when moonset is not null and moonset > moonrise then true
    else false
  end;
$$;

comment on function public.moonless_after_dusk(time, time, time) is
  '저녁 천문박명 직후 달이 하늘에 없는가. §3.8. ⚠ 점수·게이지로 화면에 노출하지 않는다 —
   UI에는 계산된 사실 한 줄만 나간다("달이 새벽 1시에 집니다").';

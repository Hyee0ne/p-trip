-- P의 여행 — 판정 함수 (TECH_SPEC §3.2, §3.8)

-- ── 장날 판정 ────────────────────────────────────────────
-- ⚠ 월말 주의: 31일은 % 10 = 1 이다. 끝자리 1인 장(1일+6일)이 31일에도 서는지는
--   현실에선 시장마다 다르지만, 표준데이터가 그 예외를 주지 않으므로 규칙대로 판정한다.
--   검수 스크립트가 30일장(끝자리 0)이 있는 달의 31일 오판을 잡는다.
create function public.is_market_day(open_cycle int[], d date)
returns boolean language sql immutable as $$
  select open_cycle is not null
     and (extract(day from d)::int % 10) = any(open_cycle);
$$;

-- ── 별 보기 좋은 밤 (§3.8) ───────────────────────────────
-- 어두운 창 = 저녁 천문박명 ~ 다음날 아침 천문박명.
-- 그 창에서 달이 지평선 아래인 만큼 별이 잘 보인다.
--
-- ⚠ 점수를 화면에 노출하지 않는다 (원칙 3). 이 값은 "말을 걸지 말지"를 정하는 데만 쓰고,
--   UI에는 계산된 **사실 한 줄**만 나간다 — "달이 새벽 1시에 집니다".
-- ⚠ 구름은 모른다. "은하수가 보입니다" 같은 단정을 만들지 않는다.
create function public.moonless_after_dusk(
  astro_dusk time, moonrise time, moonset time
) returns boolean language sql immutable as $$
  select case
    -- 박명 자료가 없으면 판단하지 않는다. false가 아니라 '모름'이므로 호출부가 줄을 안 그린다.
    when astro_dusk is null then null
    -- 달이 아예 안 뜨는 날
    when moonrise is null and moonset is null then true
    -- 박명 전에 이미 져 있으면 어둡다
    when moonset is not null and moonrise is not null and moonset < moonrise
         and moonset <= astro_dusk then true
    -- 자정 넘어 뜨면 초저녁은 어둡다
    when moonrise is not null and moonrise > astro_dusk then true
    else false
  end;
$$;

-- ── 검수용 뷰: 신뢰도 게이트를 넘는 스팟 ─────────────────
-- 게이트 미만을 숨기지는 않는다. 레이더 카드·푸시 후보만 이걸로 고른다 (§3.1).
create view public.trusted_spots
with (security_invoker = true) as
  select * from public.spots where trust_score >= 60;

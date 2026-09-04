-- 「요즘 차들이 몰래 가는 곳」 — **절대 순위를 보조로 허용한다** (2026-09-04 결정).
--
-- 원칙 3이 '절대량 인기 정렬 금지'였다. 왜 바꾸는지 남긴다:
--   변화율은 **두 시점**이 필요하다. 연관관광지를 두 달치 받아야 하는데 개발계정 한도로
--   한 시점만 겨우 받는다. 그래서 두 시점이 다 있는 노선이 7번 하나뿐이었고,
--   전국 어디를 달려도 큐레이션 한 줄이 안 나왔다.
--
-- ⚠ **변화가 있으면 변화가 이긴다.** 절대 순위는 변화를 못 재는 곳만 채운다.
--   두 시점이 갖춰지면 저절로 변화 기준으로 돌아온다 — 데이터가 차면 원래 설계로 수렴한다.
-- ⚠ 별점·후기는 여전히 없다. 스키마에 만들지 않는다 (원칙 3의 나머지는 그대로).
create or replace function public.rising_spots(p_limit int default 12)
returns table (
  spot_id uuid, from_rank int, to_rank int, jump int, from_spot_name text
) language sql stable as $$
  with months as (
    select distinct base_ym from public.spot_links order by base_ym desc limit 2
  ),
  recent as (select * from public.spot_links where base_ym = (select max(base_ym) from months)),
  older  as (select * from public.spot_links where base_ym = (select min(base_ym) from months)),

  -- ① 순위가 오른 것. 원래 설계다.
  risen as (
    select
      r.to_spot_id as spot_id,
      o.rank       as from_rank,
      r.rank       as to_rank,
      (o.rank - r.rank) as jump,
      fs.name      as from_spot_name
    from recent r
    join older o
      on o.from_spot_id = r.from_spot_id and o.to_spot_id = r.to_spot_id
    join public.spots fs on fs.id = r.from_spot_id
    where r.rank is not null and o.rank is not null and r.rank < o.rank
  ),

  -- ② 변화를 못 재는 곳은 절대 순위로 채운다.
  --    ⚠ 위에 이미 뜬 스팟은 다시 넣지 않는다.
  absolute as (
    select
      r.to_spot_id as spot_id,
      null::int    as from_rank,
      r.rank       as to_rank,
      0            as jump,
      fs.name      as from_spot_name
    from recent r
    join public.spots fs on fs.id = r.from_spot_id
    where r.rank is not null
      and not exists (select 1 from risen x where x.spot_id = r.to_spot_id)
  )

  -- 변화가 먼저, 그 안에서 오른 폭이 큰 순. 그다음이 절대 순위 상위.
  select spot_id, from_rank, to_rank, jump, from_spot_name
  from (
    select *, 0 as tier, jump as sort_a, 0 as sort_b from risen
    union all
    select *, 1 as tier, 0 as sort_a, to_rank as sort_b from absolute
  ) u
  order by tier, sort_a desc, sort_b
  limit p_limit;
$$;

comment on function public.rising_spots(int) is
  '큐레이션 3축 중 셋째. 변화(순위 상승)가 우선, 못 재는 곳은 절대 순위로 채운다.
   ⚠ 2026-09-04 이전에는 변화만 봤다 — 두 시점이 없어 전국에서 한 줄도 안 나왔다.
   ⚠ 별점·후기는 여전히 없다.';

grant execute on function public.rising_spots(int) to anon, authenticated, service_role;

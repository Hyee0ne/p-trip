-- 「요즘 차들이 몰래 가는 곳」 (CO-01 큐레이션 3축 중 셋째).
--
-- ⚠ **절대순위로 정렬하지 않는다** (원칙 3 — 절대량 인기 정렬 금지).
--   두 시점 사이에 **순위가 오른 폭**만 본다. 원래 1위였던 곳은 여기 안 뜬다.
create or replace function public.rising_spots(p_limit int default 12)
returns table (
  spot_id uuid, from_rank int, to_rank int, jump int, from_spot_name text
) language sql stable as $$
  with months as (
    select distinct base_ym from public.spot_links order by base_ym desc limit 2
  ),
  recent as (select * from public.spot_links where base_ym = (select max(base_ym) from months)),
  older  as (select * from public.spot_links where base_ym = (select min(base_ym) from months))
  select
    r.to_spot_id,
    o.rank as from_rank,
    r.rank as to_rank,
    (o.rank - r.rank) as jump,          -- 숫자가 작아질수록 상위로 올라온 것
    fs.name as from_spot_name
  from recent r
  join older o
    on o.from_spot_id = r.from_spot_id and o.to_spot_id = r.to_spot_id
  join public.spots fs on fs.id = r.from_spot_id
  where r.rank is not null and o.rank is not null and r.rank < o.rank
  order by (o.rank - r.rank) desc
  limit p_limit;
$$;

grant execute on function public.rising_spots(int) to anon, authenticated, service_role;

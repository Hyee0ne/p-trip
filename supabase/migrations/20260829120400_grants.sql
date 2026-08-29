-- 권한 (GRANT). RLS와 별개다 — GRANT가 문을 열고, RLS가 어느 행을 볼지 정한다.
--
-- ⚠ 마이그레이션은 postgres 역할이 아닌 로그인 역할로 적용되므로 Supabase의
--   기본 default privileges가 걸리지 않는다. 그래서 명시적으로 준다.
--   (이걸 빼먹으면 anon도 service_role도 전부 42501 permission denied가 난다)

grant usage on schema public to anon, authenticated, service_role;

-- ── 공개 데이터: 누구나 읽기, 쓰기는 파이프라인만 ────────
do $$
declare t text;
begin
  foreach t in array array[
    'routes', 'courses', 'spots', 'spot_links',
    'markets', 'events', 'astro_events', 'sun_moon'
  ] loop
    execute format('grant select on public.%I to anon, authenticated', t);
    execute format('grant all on public.%I to service_role', t);
  end loop;
end $$;

grant select on public.trusted_spots to anon, authenticated;
grant select on public.trusted_spots to service_role;

-- ── 사용자 데이터: 로그인한 사람만. 어느 행인지는 RLS가 정한다 ──
do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'saves', 'trips', 'trip_points', 'trip_stops', 'trip_photos'
  ] loop
    -- ⚠ anon에게는 주지 않는다. 익명은 남의 여행기를 조회할 이유가 없다.
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('grant all on public.%I to service_role', t);
  end loop;
end $$;

grant execute on function public.is_market_day(int[], date)      to anon, authenticated, service_role;
grant execute on function public.moonless_after_dusk(time, time, time) to anon, authenticated, service_role;

-- 앞으로 만들 테이블에도 같은 규칙이 걸리게 해둔다.
alter default privileges in schema public grant select on tables to anon, authenticated;
alter default privileges in schema public grant all    on tables to service_role;

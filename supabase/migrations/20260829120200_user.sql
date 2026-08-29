-- P의 여행 — 사용자 데이터 (TECH_SPEC §2)
-- 전부 RLS로 본인 것만 읽고 쓴다.

create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nickname   text,
  created_at timestamptz not null default now()
);

-- 가입하면 프로필 한 줄을 만든다. 없으면 찜·여행기가 갈 곳이 없다.
create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── 찜 · 스쳐간 발견 ─────────────────────────────────────
-- ⚠ TECH_SPEC §2는 spot/course 둘만 뒀는데, 앱은 **국도(route)도 찜한다**
--   (MY 탭 '찜한 국도', core/saves.dart SaveTargetKind). 셋 중 하나만 채운다.
create type public.save_kind as enum ('like', 'passed');

create table public.saves (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  spot_id    uuid references public.spots(id)   on delete cascade,
  course_id  uuid references public.courses(id) on delete cascade,
  route_id   int  references public.routes(id)  on delete cascade,
  -- passed = 스쳐간 발견 (자동 적립).
  -- ⚠ DR-05 동승자 브라우징의 '넘기기'는 적립하지 않는다 — 클라이언트가 안 보낸다.
  kind       public.save_kind not null default 'like',
  created_at timestamptz not null default now(),
  constraint saves_one_target check (num_nonnulls(spot_id, course_id, route_id) = 1)
);
create unique index saves_uniq_spot   on public.saves (user_id, spot_id, kind)   where spot_id  is not null;
create unique index saves_uniq_course on public.saves (user_id, course_id, kind) where course_id is not null;
create unique index saves_uniq_route  on public.saves (user_id, route_id, kind)  where route_id  is not null;
create index saves_user_idx on public.saves (user_id, kind, created_at desc);

-- ── 여행 ─────────────────────────────────────────────────
create type public.trip_status as enum ('draft', 'active', 'ended');

create table public.trips (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  status      public.trip_status not null default 'draft',
  -- 진입로 ②·③은 코스도 노선도 없이 시작한다. 둘 다 null이어도 정상이다.
  course_id   uuid references public.courses(id) on delete set null,
  route_id    int  references public.routes(id)  on delete set null,
  started_at  timestamptz,                    -- 레이더 진입 시 기록. draft 단계엔 null
  ended_at    timestamptz,
  distance_km numeric not null default 0,
  -- 거점. 숙소가 아니라 **위치 입력값**이다 (원칙 4 — 예약·결제 없음).
  base_name   text,
  base_lat    double precision,
  base_lng    double precision,
  created_at  timestamptz not null default now()
);
create index trips_user_idx on public.trips (user_id, created_at desc);

create table public.trip_points (
  trip_id uuid not null references public.trips(id) on delete cascade,
  seq     int  not null,
  lat     double precision not null,
  lng     double precision not null,
  ts      timestamptz not null,
  primary key (trip_id, seq)
);

create type public.stop_kind as enum ('visited', 'passed', 'skunked');  -- skunked = 허탕

create table public.trip_stops (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid not null references public.trips(id) on delete cascade,
  spot_id    uuid references public.spots(id) on delete set null,
  arrived_at timestamptz,
  kind       public.stop_kind not null
);
create index trip_stops_trip_idx on public.trip_stops (trip_id, arrived_at);

create table public.trip_photos (
  id             uuid primary key default gen_random_uuid(),
  trip_id        uuid not null references public.trips(id) on delete cascade,
  -- 기기 안 사진의 식별자만 갖는다. 사진 자체를 서버에 올리지 않는다.
  local_asset_id text not null,
  lat            double precision,
  lng            double precision,
  taken_at       timestamptz,
  spot_id        uuid references public.spots(id) on delete set null
);
create index trip_photos_trip_idx on public.trip_photos (trip_id, taken_at);

-- ── RLS — 본인 것만 ──────────────────────────────────────
alter table public.profiles    enable row level security;
alter table public.saves       enable row level security;
alter table public.trips       enable row level security;
alter table public.trip_points enable row level security;
alter table public.trip_stops  enable row level security;
alter table public.trip_photos enable row level security;

create policy "본인 프로필" on public.profiles for all
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "본인 찜" on public.saves for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "본인 여행" on public.trips for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- 자식 테이블은 부모 trip의 소유자를 따라간다.
create policy "본인 여행의 경로" on public.trip_points for all
  using (exists (select 1 from public.trips t
                 where t.id = trip_id and t.user_id = (select auth.uid())))
  with check (exists (select 1 from public.trips t
                      where t.id = trip_id and t.user_id = (select auth.uid())));

create policy "본인 여행의 정차" on public.trip_stops for all
  using (exists (select 1 from public.trips t
                 where t.id = trip_id and t.user_id = (select auth.uid())))
  with check (exists (select 1 from public.trips t
                      where t.id = trip_id and t.user_id = (select auth.uid())));

create policy "본인 여행의 사진" on public.trip_photos for all
  using (exists (select 1 from public.trips t
                 where t.id = trip_id and t.user_id = (select auth.uid())))
  with check (exists (select 1 from public.trips t
                      where t.id = trip_id and t.user_id = (select auth.uid())));

-- P의 여행 — 공개 데이터 (TECH_SPEC §2)
--
-- ⚠ 별점·후기·랭킹 컬럼을 만들지 않는다 (제품 원칙 3).
--   신뢰는 trust_score(데이터 완성도)와 spot_links(이동 흔적)로만 세운다.

-- ── 국도 51선 ────────────────────────────────────────────
create table public.routes (
  id        int primary key,                  -- 노선번호 그대로. 7, 44, 46…
  name      text not null default '',         -- 별명. 없으면 빈 문자열 — UI가 'N번 국도'로 대체한다
  axis      text not null check (axis in ('NS', 'EW')),
  drivable  boolean not null default true,    -- 북한 구간이면 false
  from_to   text not null default '',         -- '부산–고성'. 모르면 빈 문자열 (UI가 줄을 안 그린다)
  total_km  numeric,
  geom      extensions.geometry(LineString, 4326)
);
comment on column public.routes.geom is
  'M1 build-routes.ts가 채운다. 비어 있으면 지도에 그리지 않는다 — 없는 선을 그리지 않는다.';

-- ── 코스 = 노선의 큐레이션 구간 ──────────────────────────
create table public.courses (
  id           uuid primary key default gen_random_uuid(),
  route_id     int not null references public.routes(id) on delete cascade,
  title        text not null,
  start_name   text not null default '',
  end_name     text not null default '',
  distance_km  numeric,
  duration_min int,                           -- ⚠ 순수 주행시간. 도착 시각으로 환산 금지 (원칙 1)
  geom         extensions.geometry(LineString, 4326),
  is_demo      boolean not null default false,
  created_at   timestamptz not null default now()
);
create index courses_route_idx on public.courses (route_id);
create index courses_geom_idx  on public.courses using gist (geom);

-- ── 스팟 (관광지·음식점·문화시설·뷰포인트·숙박·캠핑장·시장 전부 동급) ──
create type public.spot_type as enum
  ('market', 'food', 'view', 'culture', 'stay', 'camp', 'attraction');

create table public.spots (
  id                 uuid primary key default gen_random_uuid(),
  tourapi_contentid  text unique,
  type               public.spot_type not null,
  name               text not null,
  lat                double precision not null,
  lng                double precision not null,
  geom               extensions.geometry(Point, 4326) not null,
  addr               text,
  tel                text,
  image_url          text,
  photo_count        int not null default 0,
  overview           text,
  open_hours         text,
  tags               text[] not null default '{}',

  -- 0~100. 대표사진 35 / 추가사진 3장+ 10 / 전화 15 / 영업시간 20 / 번지주소 10 / 개요 10
  -- >= 60 이면 레이더 카드·푸시 후보. 미만은 브라우징에서만 노출하고 숨기지는 않는다.
  trust_score        int not null default 0 check (trust_score between 0 and 100),

  -- 국도 진출점에서 스팟까지 왕복 추정(분). 지방도 40km/h 가정.
  -- ⚠ 라우팅 API로 잰 값이 아니다. UI 표기는 항상 '국도에서 약 N분'.
  detour_min         int,
  exit_geom          extensions.geometry(Point, 4326),   -- ST_ClosestPoint(route.geom, spot.geom)
  exit_frac          double precision,                   -- ST_LineLocatePoint. 진출로 역산용
  route_id           int references public.routes(id) on delete set null,

  updated_at         timestamptz not null default now()
);
create index spots_geom_idx  on public.spots using gist (geom);
create index spots_route_idx on public.spots (route_id, exit_frac);
create index spots_trust_idx on public.spots (trust_score);
create index spots_type_idx  on public.spots (type);

-- ── 연관 관광지 (발자국) ─────────────────────────────────
-- TourAPI TarRlteTarService1. baseYm으로 두 시점을 각각 받아 비교한다.
-- ⚠ rank는 그 달의 순위일 뿐이다. **절대순위로 정렬하지 않는다** — 변화만 쓴다 (원칙 3).
create table public.spot_links (
  from_spot_id uuid not null references public.spots(id) on delete cascade,
  to_spot_id   uuid not null references public.spots(id) on delete cascade,
  category     text,
  rank         int,
  base_ym      text not null,                 -- '202606'
  primary key (from_spot_id, to_spot_id, base_ym)
);
create index spot_links_from_idx on public.spot_links (from_spot_id, base_ym);

-- ── 전통시장 장날 ────────────────────────────────────────
create table public.markets (
  spot_id    uuid primary key references public.spots(id) on delete cascade,
  -- 날짜 끝자리 배열. 원본 '3일+8일' -> {3,8}, '5일+10일' -> {5,0}
  -- ⚠ 10·20·30을 그대로 넣으면 % 10 = 0 이라 영원히 매칭되지 않는다.
  -- ⚠ '매일'(상설)은 NULL. 빈 배열과 구분한다.
  open_cycle int[],
  open_rule  text,                            -- '매월 2·4주 토요일' 등. MVP는 판정하지 않고 문구만 노출
  note       text,
  constraint markets_cycle_digits check (
    open_cycle is null or open_cycle <@ array[0,1,2,3,4,5,6,7,8,9]
  )
);
create index markets_cycle_idx on public.markets using gin (open_cycle);

-- ── 행사 (기간 한정) ─────────────────────────────────────
create table public.events (
  id         uuid primary key default gen_random_uuid(),
  spot_id    uuid references public.spots(id) on delete cascade,
  title      text not null,
  start_date date not null,
  end_date   date not null,
  check (end_date >= start_date)
);
create index events_period_idx on public.events (start_date, end_date);

-- ── 천문현상 ─────────────────────────────────────────────
-- ⚠ **좌표가 없다.** 전국 공통 값이라 "여기서만"이 아니라 "오늘만"으로만 쓴다.
--   스팟으로 만들어 레이더에 띄우면 위치를 지어내는 것이다 (원칙 2).
-- 원본 198건 중 186건은 title이 비고 description만 있는 월상 달력(삭·망·근지점)이다.
-- is_event = true 인 것만 사용자에게 보여준다. 나머지는 월령 계산 입력값이다.
create table public.astro_events (
  id          uuid primary key default gen_random_uuid(),
  locdate     date not null,
  title       text not null default '',
  event_time  time,
  description text not null default '',
  is_event    boolean not null default false,
  unique (locdate, title, description)
);
create index astro_events_date_idx on public.astro_events (locdate) where is_event;

-- ── 일출·일몰·월출·월몰·박명 (천문연 출몰시각, 좌표 격자별 일 단위 캐시) ──
create table public.sun_moon (
  locdate     date not null,
  grid_lat    numeric(4,1) not null,          -- 0.1도 격자
  grid_lng    numeric(5,1) not null,
  sunrise     time, suntransit time, sunset  time,
  moonrise    time, moontransit time, moonset time,
  civil_dawn  time, civil_dusk time,          -- 시민박명
  naut_dawn   time, naut_dusk  time,          -- 항해박명
  astro_dawn  time, astro_dusk time,          -- 천문박명 — 별 보기 좋은 밤의 기준 (§3.8)
  primary key (locdate, grid_lat, grid_lng)
);

-- 공개 데이터는 누구나 읽는다. 쓰기는 파이프라인(service_role)만 — RLS를 켜고 정책을 안 주면 된다.
alter table public.routes       enable row level security;
alter table public.courses      enable row level security;
alter table public.spots        enable row level security;
alter table public.spot_links   enable row level security;
alter table public.markets      enable row level security;
alter table public.events       enable row level security;
alter table public.astro_events enable row level security;
alter table public.sun_moon     enable row level security;

create policy "공개 읽기" on public.routes       for select using (true);
create policy "공개 읽기" on public.courses      for select using (true);
create policy "공개 읽기" on public.spots        for select using (true);
create policy "공개 읽기" on public.spot_links   for select using (true);
create policy "공개 읽기" on public.markets      for select using (true);
create policy "공개 읽기" on public.events       for select using (true);
create policy "공개 읽기" on public.astro_events for select using (true);
create policy "공개 읽기" on public.sun_moon     for select using (true);

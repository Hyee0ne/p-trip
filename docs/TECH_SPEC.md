# TECH_SPEC.md — P의 여행 기술 스펙 v1

기획 근거: `국도여행_화면기획_기능기획_v2.md` / 제품 원칙은 `CLAUDE.md` 참조.

---

## 1. 아키텍처 개요

```
[Flutter 앱]
  ├─ 발견 탭: Supabase 조회 (spots/courses/routes 캐시 테이블)
  ├─ 레이더: geolocator 위치 → Supabase RPC(반경+방향 쿼리) → 근접 카드
  │          "들르기" → kakao_flutter_sdk_navi 핸드오프
  ├─ 여행기: 로컬 trip 로그 + photo_manager 메타 매칭 → Supabase 저장
  └─ 인증: Supabase Auth (카카오 로그인)

[Supabase]
  ├─ Postgres + PostGIS (공간 쿼리)
  ├─ Edge Functions: TourAPI 프록시(키 은닉), 실시간 조회용
  └─ Storage: 여행기 공유 카드 이미지

[pipeline (Node, 로컬/cron)]
  ├─ TourAPI 배치 수집 → spots 적재 (위치기반/행사/사진/연관관광지/고캠핑/두루누비)
  ├─ 전통시장표준데이터 → markets (장날 주기)
  └─ 국도 노선 GeoJSON 생성 → routes (맵매칭·색칠용)
```

원칙: **읽기는 우리 DB에서** (TourAPI를 런타임에 직접 때리지 않음 — 쿼터·지연·키 노출 방지).
파이프라인이 주기 수집해 정제 적재하고, 앱은 Supabase만 본다.
행사 등 시의성 데이터만 Edge Function 프록시로 준실시간 보강.

## 2. 데이터 모델 (Postgres)

```sql
-- 국도 노선 (51선)
routes: id(int, 노선번호 7), name('동해 바닷길'), axis('NS'|'EW'),
        drivable(bool, 북한구간 false), total_km, geom(LineString)

-- 코스 = 노선의 큐레이션 구간
courses: id, route_id, title('7번 국도 바다길'), start_name, end_name,
         distance_km, duration_min, geom(LineString), is_demo(bool)

-- 스팟 (관광지/음식점/문화시설/뷰포인트/숙박/캠핑장/시장 — 전부 동급)
spots: id, tourapi_contentid, type(enum), name, lat, lng, geom(Point),
       addr, tel, image_url, photo_count(int), overview, open_hours, tags(text[]),
       trust_score(int),           -- 0~100, 아래 배점표. 게이트 임계 60
       detour_min(int),            -- 국도 진출점↔스팟 왕복 추정(분). ⚠ 실측 소요시간 아님
       exit_geom(Point),           -- 국도 진출점 = ST_ClosestPoint(route.geom, spot.geom)
       exit_frac(float),           -- 노선상 위치비 = ST_LineLocatePoint (진출로 역산용)
       route_id(int, nullable)     -- 가장 가까운 국도 노선
       -- ⚠ 별점/후기 필드 없음. 만들지 말 것.

-- trust_score 배점표 (합 100, 파이프라인이 산정)
--   대표사진 35 / 추가사진 3장 이상 10 / 전화번호 15 / 영업시간 20 / 번지까지 주소 10 / 개요 10
--   >= 60 : 레이더 카드·푸시 후보 (신뢰도 게이트 통과)
--   <  60 : 브라우징(CO-01/02/03)에서만 노출. 숨기지는 않는다

-- detour_min 정의 (라우팅 API 없이 계산 — 비내비 원칙)
--   ceil( ST_Distance(exit_geom, geom) / 40km/h * 60 ) * 2   -- 왕복, 지방도 40km/h 가정
--   UI 표기는 항상 "국도에서 약 N분". 도착 시각으로 환산 금지

-- 연관 관광지 (발자국 데이터)
spot_links: from_spot_id, to_spot_id, category, rank

-- 전통시장 장날
markets: spot_id(FK), open_cycle(int[]), open_rule(text, nullable), note
-- open_cycle = 날짜 끝자리 배열. ⚠ 적재 시 정규화 필수: '5,10' -> {5,0}, '10,30' -> {0}
--   (표준데이터 원문이 "5, 10일" 형태라 10·20·30을 그대로 넣으면 % 10 = 0 이라 영원히 매칭 안 됨)
-- open_rule = "매월 2·4주 토요일" 등 끝자리로 표현 불가한 장. MVP는 판정하지 않고 상세에 문구만 노출

-- 행사 (기간 한정)
events: spot_id, title, start_date, end_date

-- 사용자
profiles: id(auth.uid), nickname
saves: user_id, spot_id(nullable), course_id(nullable),
       kind('like'|'passed'), created_at
       -- CHECK (num_nonnulls(spot_id, course_id) = 1)
       -- UNIQUE (user_id, spot_id, course_id, kind)
       -- passed = 스쳐간 발견 (자동 적립). ⚠ DR-05 동승자 브라우징의 '넘기기'는 적립하지 않는다

-- 여행
trips: id, user_id, status('draft'|'active'|'ended'),
       course_id(nullable), route_id(nullable),      -- 진입로 ②·③은 코스도 노선도 없이 시작
       started_at(nullable), ended_at(nullable),      -- draft 단계엔 아직 출발 전
       distance_km, base_name, base_lat, base_lng     -- 거점(위치 입력값)
       -- CO-06에서 거점만 저장한 시점 = status 'draft'. 레이더 진입 시 'active' + started_at 기록
trip_points: trip_id, seq, lat, lng, ts             -- GPS 로그 (5~10초)
trip_stops: trip_id, spot_id, arrived_at, kind('visited'|'passed'|'skunked')
            -- skunked = 허탕
trip_photos: trip_id, local_asset_id, lat, lng, taken_at, spot_id?
```

## 3. 핵심 로직 명세

### 3.1 발견 쿼리 (레이더의 심장)
Supabase RPC `discover_nearby(lat, lng, heading, now)`:
1. 현 위치 반경 R(기본 8km) 내 + 진행 방향 ±90° 스팟 조회 (PostGIS)
   - ⚠ **정차·저속 시 방향 필터 해제**: speed < 2m/s 이면 heading이 노이즈이므로 360° 전방향
   - heading 값이 없으면 최근 trip_points 3개의 이동벡터로 대체 산출
2. `detour_min <= 10` 필터
3. `trust_score >= 60` — 푸시/카드 후보는 검증 스팟만 (DR-05 동승자 브라우징은 이 게이트 미적용)
4. 점수 = 사진 보유 + 태그 매칭 + **타이밍 가중치**
   (11–14시 음식점 ×2, 일몰-60분~-20분 뷰포인트 ×2, 장날인 시장 ×3)
5. **진출로 역산 타이밍** (DR-02 헤드 "{진출로} 진출로 N분 전"의 근거):
   `eta_to_exit_min = (spot.exit_frac - now_frac) * route.total_km / max(speed, 40km/h) * 60`
   - `now_frac` = 현 위치를 ST_LineLocatePoint 한 값. 음수면 이미 지나친 것 → 후보 제외
   - **3~7분 구간에서만 카드를 띄운다** (상의·결정할 시간 확보 — 페르소나 ② 대응)
   - ⚠ 라우팅 API를 쓰지 않는다. 노선 형상 + 현재 속도만으로 산출하는 정적 추정치
6. 중복 억제: 같은 type 연속 노출 금지, 30분당 최대 2회 (클라이언트에서)
- 일몰 시각: 천문연 API를 파이프라인이 일 단위 캐시 (좌표 격자별)

### 3.2 장날 판정
`is_market_day(open_cycle, date)`: `EXTRACT(day FROM date) % 10 = ANY(open_cycle)`.
적재 시 끝자리 정규화(10→0, 20→0, 30→0)를 마친 값이어야 한다 — §2 markets 주석 참조.
오늘 장날인 시장은 발견 점수 최상위 + 카드에 "다음 장은 N일 뒤" 문구 자동 생성.
`open_rule`만 있는 비순환 장은 판정 대상에서 제외(MVP).
⚠ 월말 처리: 31일은 %10 = 1. 30일장(=끝자리 0)이 있는 달의 31일을 장날로 오판하지 않는지 검수 스크립트로 확인.

### 3.3 카카오내비 핸드오프 (2단)
- 출발 시: `NaviApi.navigate(destination: 거점, viaList: [앵커 1~2])`
- 이동 중 "들르기": `NaviApi.navigate(destination: 스팟)` 단건
- 티맵 보조(SCREENS.md HND 버튼 2번): 딥링크로 **목적지 단건만** 전달. 경유지 미지원
- 미설치 분기: 스토어 설치 페이지로 이동
- 핸드오프 직전 스낵바: "내비에서 '무료도로 우선'을 켜면 국도 중심으로 안내돼요"
- ⚠ 카카오모빌리티 길찾기 REST/내장 SDK는 **원칙적으로 사용 금지** (우리가 내비가 되면 안 됨)
  → 유일한 예외는 §3.7. 그 외 어떤 화면에서도 호출 경로를 만들지 않는다

### 3.4 경로 기록 & 맵매칭
- 레이더 모드 중에만: geolocator stream, distanceFilter 30m or 8초 간격
- 정차 감지(속도 < 2m/s 3분) → 로깅 일시정지 + 몰아보기 카드 트리거
- 맵매칭(MVP 단순화): trip_points를 routes.geom에 point-to-line 스냅,
  50m 이내면 해당 노선 주행으로 인정 → 노선별 주행 km 합산 (국도 수집)
- 권한 **2단계 옵트인**(SCREENS.md §DR-06):
  - 1단계 기본값 = "앱 사용 중 허용". 온보딩·첫 진입에서는 이것만 묻는다
  - 2단계 "항상 허용"은 여행 2회 이상 마친 유저가 [🔔]을 직접 탭했을 때만 유도
  - Android(포그라운드 서비스) 우선. iOS "항상 허용"은 심사 정당화 필요 — 데모는 Android 기준

### 3.5 여행기 생성
trip 종료 시:
1. trip_points → 경로 폴리라인 (공유 시 시작·끝 300m 절단)
2. trip_stops → 타임라인 (visited/passed/skunked)
3. photo_manager로 [started_at, ended_at] 사진 조회
   → GPS EXIF 있으면 좌표로, 없으면 촬영 시각↔trip_points 보간으로 위치 부여
   → 가까운 trip_stop에 귀속
4. 공유 카드: 위젯 → 이미지 캡처(RepaintBoundary) → share_plus
5. 딥링크 `ptrip://course/{id}` 포함 ("이 길 나도 달려보기")

### 3.6 솔로 모드 (M5)
- flutter_tts로 카드 낭독. MVP 음성 인식은 스코프 아웃 —
  대신 "무응답 15초 → 자동 찜(passed 적립)"만 구현. STT는 2차.

### 3.7 거점 역진입 — 국도 제안 (CO-06b)
진입로 ②(숙소 먼저 예약한 유저)의 전환점. 화면 정의는 SCREENS.md §CO-06b.

호출 시점: `/base`에서 **거점을 확정한 직후 딱 1회**. 그 외 어디서도 호출하지 않는다.

1. Edge Function `compare_routes(origin, base)` — 카카오모빌리티 길찾기 REST 2회
   - `priority=RECOMMEND` → 고속도로 기준 소요시간 A
   - 무료도로 우선 옵션 → 국도 기준 소요시간 B
2. 결과를 `(origin_grid, base_grid, date)` 키로 캐시. 같은 조합 재조회 금지
3. base 인근을 지나는 route/course 조회 → 경로변 spots 개수 N, 오늘 장날·행사·일몰 앵커 추출
4. **앵커가 0건이면 모달을 반환하지 않는다** (설득 근거 없이 40분을 더 쓰라고 하지 않는다)

⚠ 원칙 경계 — 이 예외가 §3.3을 무효화하지 않도록 구조로 막는다:
- 키는 Edge Function 뒤에만 존재. 앱 번들에 길찾기 키를 넣지 않는다
- 레이더(DR-*) 코드에서 이 Edge Function을 import하지 않는다 — 호출 경로 자체를 만들지 않음
- 반환된 A·B는 **비교 근거**일 뿐 ETA가 아니다. 도착 시각 환산·이동 중 갱신 금지
- 거절 시 아무 일도 일어나지 않고, 다시 묻지 않는다

## 4. 외부 API·키 목록

| 서비스 | 용도 | 발급처 | 소비 위치 |
|---|---|---|---|
| TourAPI (국문관광정보/사진/연관관광지/고캠핑/두루누비/수요강도) | 스팟 수집 | data.go.kr | pipeline + Edge Fn |
| 전국전통시장표준데이터 | 장날 | data.go.kr | pipeline |
| 천문연 출몰시각 | 일몰 | data.go.kr | pipeline |
| 카카오내비 SDK | 핸드오프 | developers.kakao.com | 앱 |
| 카카오맵 | 지도 표시 | developers.kakao.com | 앱 |
| 한국관광 데이터랩 (검색·방문 변화율) | CO-01 "조용히 뜨는 길" | datalab.visitkorea.or.kr | pipeline |
| 카카오모빌리티 길찾기 REST | **§3.7 전용** (고속도로↔국도 비교 1회) | developers.kakaomobility.com | Edge Fn **전용** |
| Supabase | BaaS | supabase.com | 전체 |

⚠ 기상청 단기예보(우천 시 실내 가중치)는 **스코프 아웃** — 기획문서 §10에 있으나 MVP에서 쓰지 않는다.

환경변수: `SUPABASE_URL/ANON_KEY`(앱), `TOURAPI_KEY, DATA_GO_KR_KEY`(pipeline/EdgeFn),
`KAKAO_NATIVE_APP_KEY`(앱). 서비스 키는 앱에 절대 포함 금지.

## 5. 화면 ↔ 구현 매핑 (기획 문서 화면ID 기준)

| 화면ID | 라우트 | 핵심 의존성 |
|---|---|---|
| ON 온보딩 | `/onboarding` | 최초 1회. 권한은 요청만, 강제 없음 |
| CO-01 홈 | `/` | courses, events, markets(오늘 장날), 데이터랩 변화율. **뷰 모드 2개** |
| SR 검색 | `/search` | 스팟·코스 텍스트 검색 + 필터. 모달, 탭바 덮음 |
| CO-07 국도 선택 | `/routes` | routes 51행, drivable 구분 |
| CO-02 코스 상세 | `/course/:id` | course.geom + 경로변 spots, RouteBadge |
| CO-03 스팟 상세 | `/spot/:id` | spot + spot_links + 확신도 문구. **마을/스팟 통합** |
| CO-06 거점 설정 | `/course/:id/base` · `/base` | 카카오 장소검색 or 지도 핀 → trips(draft).base_* |
| CO-06b 국도 제안 | (`/base` 확정 후 모달) | §3.7 compare_routes Edge Fn |
| HND 핸드오프 시트 | (모달) | kakao_flutter_sdk_navi / 티맵 딥링크 |
| DR-00 위치 권한 | (`/radar` 인라인) | 앱 사용 중 허용만 |
| DR-01 레이더 | `/radar` | discover_nearby RPC, 위치 스트림, rec 로깅 |
| DR-02 발견 카드 | (레이더 내 전면 카드) | 점수 상위 1건, 액션: 핸드오프/찜/passed |
| DR-03 몰아보기 | (레이더 내 오버레이) | passed 스팟 2~4건 |
| DR-05 동승자 | (`/radar` 서브모드) | discover_ahead RPC(반경 20km, 게이트 미적용) |
| DR-06 백그라운드 | (권한 유도 + OS 알림) | 백그라운드 위치 + 로컬 알림. **Android 우선** |
| MY-02 여행기 | `/trip/:id` | trips/stops/photos, 공유 카드 |
| MY-01/03 마이 | `/my` | saves(like/passed), 국도 수집 진행률, 설정 |

## 6. 스코프 아웃 (구현 금지·보류)

- 금지: 턴바이턴/ETA/경로재탐색, 별점·후기, 예약·결제, 절대량 인기 랭킹
  - 길찾기 REST의 **유일한 예외는 §3.7**(거점 역진입 비교 1회, Edge Fn 뒤). 그 외 전면 금지
- 2차 보류: STT 음성 응답, **동승자 모드 실시간 동기화**(단말 2대 — MVP는 1대 모드 전환),
  국도 색칠 지도 렌더링(진행률 숫자까지만 MVP), 숏폼 영상, 찜 재소환 추천,
  마을 상세 분리(CO-03 통합으로 대체), 기상청 우천 가중치
- **MVP로 승격됨** (2026-08-26 결정): 거점 역진입(§3.7), DR-05 동승자 모드,
  DR-06 백그라운드 근접 알림, CO-01 급상승 실데이터화

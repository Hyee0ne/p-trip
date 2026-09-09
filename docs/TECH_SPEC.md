# TECH_SPEC.md — P의 여행 기술 스펙 v1

기획 근거: `국도여행_화면기획_기능기획_v2.md` / 제품 원칙은 `CLAUDE.md` 참조.

---

## 1. 아키텍처 개요

```
[Flutter 앱]
  ├─ 발견 탭: Supabase 조회 (spots/courses/routes 캐시 테이블)
  ├─ 레이더: geolocator 위치 → Supabase RPC(반경+방향 쿼리) → 근접 카드
  │          "들르기" → 티맵 URL 스킴 핸드오프 (카카오내비 → 티맵, 2026-09-09)
  ├─ 여행기: 로컬 trip 로그 + photo_manager 메타 매칭 → Supabase 저장
  └─ 인증: Supabase Auth (카카오 로그인)

[Supabase]
  ├─ Postgres + PostGIS (공간 쿼리)
  ├─ Edge Functions: TourAPI 프록시(키 은닉), 실시간 조회용
  └─ Storage: 여행기 공유 카드 이미지

[pipeline (Node, 로컬/cron)]
  ├─ TourAPI 배치 수집 → spots 적재 (위치기반/행사/사진/연관관광지/고캠핑/두루누비)
  ├─ 전통시장표준데이터 → markets (장날 주기) ※ 오픈API 없음. 연 1회 갱신 CSV 파일 (pipeline/data/)
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

-- 천문현상 (천문연 천문현상 정보 API)
-- ⚠ **좌표가 없다.** 전국 공통 값이라 "여기서만"이 아니라 "오늘만"으로만 쓴다.
--    스팟으로 만들어 레이더에 띄우면 위치를 지어내는 것이다 (원칙 2 위반).
astro_events: locdate(date), title, event_time(time), description, is_event(bool)
-- ⚠ 실측(2026-08-29): 2026년 198건 중 **186건은 title이 비고 description만 있는 월상 달력**
--   (삭·망·근지점 등). 이름 붙은 '사건'은 12건뿐 — 유성우 3, 개기월식 1, 계절 별자리 4 등.
--   적재 때 is_event로 가른다: true만 사용자에게 보이고, false는 월령 계산 입력값이다.

-- 스팟 (관광지/음식점/문화시설/뷰포인트/숙박/캠핑장/시장 — 전부 동급)
spots: id, tourapi_contentid, type(enum), name, lat, lng, geom(Point),
       addr, tel, image_url, photo_count(int), overview, open_hours, tags(text[]),
       trust_score(int),           -- 0~100, 아래 배점표. 게이트 임계 60
       detour_min(int),            -- 국도 진출점↔스팟 왕복 추정(분). ⚠ 실측 소요시간 아님
       exit_geom(Point),           -- 국도 진출점 = ST_ClosestPoint(route.geom, spot.geom)
       exit_frac(float),           -- 노선상 위치비 = ST_LineLocatePoint (진출로 역산용)
       route_id(int, nullable)     -- 가장 가까운 국도 노선
       -- ⚠ 별점/후기 필드 없음. 만들지 말 것.

-- ⚠ TourAPI 호출 전략 (2026-08-29 실측) — **일일 요청 제한이 오퍼레이션 단위로 걸린다.**
--   목록(areaBasedList2)에 이미 사진 84% · 주소 99% · 전화가 들어 있다.
--   detailCommon2(공통정보조회)는 사실상 **개요 하나** 때문에 부르는 셈이고, 개요는 10점이라
--   게이트를 거의 안 가른다. 그래서 수집에서 빼고, 게이트 통과분만 나중에 채운다(fetch:overview).
--   detailIntro2(소개정보조회)는 영업시간 20점 때문에 필요하다 — 이건 뺄 수 없다.
--   → 스팟당 2콜 → 1콜. 운영계정 없이 개발계정으로 돌린다.

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
-- open_cycle = 날짜 끝자리 배열.
-- ⚠ 실제 원본 표기는 '시장개설주기' 열이고 **'N일+M일'** 형식이다 (2026-08-29 실측, 1,393개 시장).
--    확인된 표기 8종: 매일(982) / 2일+7일(87) / 4일+9일(86) / 5일+10일(86) / 3일+8일(84)
--                     / 1일+6일(66) / 2일+5일(1) / 2일+4일+7일+9일(1)
--    정규화: '+'로 쪼개 숫자만 뽑고 10→0. '5일+10일' -> {5,0}, '2일+4일+7일+9일' -> {2,4,7,9}
--    '매일'은 상설이므로 open_cycle을 비운다(NULL) — 빈 배열과 구분할 것
--   (표준데이터 원문이 "5, 10일" 형태라 10·20·30을 그대로 넣으면 % 10 = 0 이라 영원히 매칭 안 됨)
-- open_rule = "매월 2·4주 토요일" 등 끝자리로 표현 불가한 장. MVP는 판정하지 않고 상세에 문구만 노출

-- 행사 (기간 한정)
events: spot_id, title, start_date, end_date

-- 일출·일몰·월출·월몰·박명 (천문연 출몰시각, 좌표 격자 0.1도 × 일 단위 캐시)
-- 실측 확인(2026-08-29): sunrise/suntransit/sunset + moonrise/moontransit/moonset
--   + civil·naut·astro 박명(아침·저녁)이 전부 한 응답에 온다. ⚠ 앱은 sunset 만 읽는다 (§3.8 삭제).
sun_moon: locdate, grid_lat, grid_lng,
          sunrise, suntransit, sunset, moonrise, moontransit, moonset,
          civil_dawn/dusk, naut_dawn/dusk, astro_dawn/dusk

-- 사용자
-- ⚠ **로그인을 넣지 않는다** (2026-08-29 결정). 찜·여행기는 기기 안에 둔다.
--   · 기획이 "로그인 없이 시작"을 전제한다 — 온보딩도 권한만 묻는다
--   · 여행기는 본질적으로 그 기기의 기록이다. trip_photos가 기기 안 사진의 식별자만
--     갖는 구조라, 서버에 여행기만 올라가면 사진 없는 반쪽이 된다
--   · 아래 테이블과 RLS는 **그대로 둔다.** 계정이 생기는 날 로컬 값을 올려 동기화한다
profiles: id(auth.uid), nickname
saves: user_id, spot_id(nullable), course_id(nullable), route_id(nullable),
       kind('like'|'passed'), created_at
       -- ⚠ 앱은 **국도(route)도 찜한다** (MY '찜한 국도', core/saves.dart). 셋 중 하나만 채운다.
       -- CHECK (num_nonnulls(spot_id, course_id, route_id) = 1)
       -- UNIQUE 부분 인덱스 3개 (대상별로 user_id+kind 유일)
       -- passed = 스쳐간 발견 (자동 적립).

-- 여행
trips: id, user_id, status('draft'|'active'|'ended'),
       course_id(nullable), route_id(nullable),      -- 진입로 ②·③은 코스도 노선도 없이 시작
       started_at(nullable), ended_at(nullable),      -- draft 단계엔 아직 출발 전
       distance_km, base_name, base_lat, base_lng     -- 거점(위치 입력값)
       -- ⚠ 거점(base_*)은 안 쓴다. 개념을 없앴다 (2026-09-07). 컬럼은 남겨 둔다
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
3. `trust_score >= 60` — 푸시/카드 후보는 검증 스팟만. **게이트를 안 거는 화면은 이제 없다**
   (DR-05 동승자 모드 삭제, 2026-09-03)
4. 점수 = 사진 보유 + 태그 매칭 + **타이밍 가중치**
   (11–14시 음식점 ×2, 일몰-60분~-20분 뷰포인트 ×2, 장날인 시장 ×3)
5. **노출 범위 — 현 위치 반경** (2026-08-30 개정):
   `discover_ahead(lat, lng, heading, km)` RPC. 현 위치에서 **반경 5km, 진행 방향 ±60°**.
   - ⚠ ~~`exit_frac` 기반 진출로 역산~~ → **폐기.** `exit_frac`은 **그 스팟이 속한 노선의**
     비율이라, 다른 국도를 달리면 현재 진행률과 빼는 것 자체가 말이 안 된다.
     실기기에서 43번 국도를 달리는데 삼척(7번) 스팟이 떴다
   - ⚠ ~~3~7분 구간~~ → 폐기. 속도를 타서 막히면 코앞만, 뻥 뚫리면 한참 먼 게 떴다
   - **경로가 아니라 현 위치 기준이다** (원칙 2). 코스를 벗어나도 그대로 돈다
   - 신뢰도 ≥60, 우회 ≤10분을 건다. 이 상한이 **수집 회랑 3.5km의 근거**다
   - ⚠ 라우팅 API를 쓰지 않는다. PostGIS 거리·방위만 쓴다
6. 중복 억제: **같은 곳을 두 번 말하지 않는 것뿐** (클라이언트 `_shown`).
   ~~같은 type 연속 노출 금지, 30분당 최대 2회~~ → **폐기 (2026-08-30).**
   반경 안의 것은 다 알린다. 유형으로 거르면 남은 게 전부 같은 유형일 때 굶는다
- 일몰 시각: 천문연 출몰시각 API를 파이프라인이 일 단위 캐시 (좌표 격자별)
  - 같은 응답에 **월출·월몰·박명(시민·항해·천문)**이 함께 온다. 전부 캐시한다 — §3.3의 전제다

### 3.2 장날 판정
`is_market_day(open_cycle, date)`: `EXTRACT(day FROM date) % 10 = ANY(open_cycle)`.
적재 시 끝자리 정규화(10→0, 20→0, 30→0)를 마친 값이어야 한다 — §2 markets 주석 참조.

**데모 구간 실측 (2026-08-29)** — 삼척·동해·강릉에 시장 17곳, 그중 5일장 2곳:
- **북평민속시장** 3일+8일 · 37.48247, 129.12603 · 동해시 오일장길 32 ← 데모 기준
  ⚠ 정식 명칭은 '북평민속시장'이다. 대본에서 '북평 5일장'으로 부르되 데이터 매칭은 이 이름으로 한다.
  ⚠ '북평'은 전남 해남에도 있다(북평면남창5일시장, 2일+7일). **반드시 주소로 동해시를 확인**할 것.
- 삼척중앙시장 2일+7일 · 삼척시 진주로 12-21 ← 시연일이 3·8일이 아닐 때의 대안
나머지 15곳은 '매일'(상설) — 묵호시장·동쪽바다중앙시장·주문진수산시장 등.
오늘 장날인 시장은 발견 점수 최상위 + 카드에 "다음 장은 N일 뒤" 문구 자동 생성.
`open_rule`만 있는 비순환 장은 판정 대상에서 제외(MVP).
⚠ 월말 처리: 31일은 %10 = 1. 30일장(=끝자리 0)이 있는 달의 31일을 장날로 오판하지 않는지 검수 스크립트로 확인.

### 3.3 ~~카카오내비~~ 티맵 핸드오프 (2026-09-09 교체)

⚠ **카카오내비 → 티맵.** 카카오내비는 안내 중 새 목적지를 거절해 「들르기」가 막혔다 (SCREENS.md §HND).
  티맵은 `tmap://route?rGoName=&rGoX=&rGoY=` 로 안내 중에도 경로를 바꾼다 (실기기 확인).
  아래 '2단'(경유지 viaList) 설계는 카카오내비 SDK 전제라 **기록용**이다 — 티맵 URL 은 목적지 단건.

- 출발 시: `NaviApi.navigate(destination: 거점, viaList: [앵커 1~2])`
- 이동 중 "들르기": `NaviApi.navigate(destination: 스팟)` 단건
- 티맵·애플 지도 보조(SCREENS.md HND): 딥링크로 **목적지 단건만** 전달. 경유지 미지원
  - 애플 지도 `https://maps.apple.com/?daddr={lat},{lng}&dirflg=d` — **좌표로만** 보낸다.
    이름으로 검색시키면 '중앙시장'처럼 전국에 널린 이름이 엉뚱한 데서 잡힌다
  - ⚠ **애플 지도를 빼면 심사에서 반려된다** (2026-09-02, Guideline 4 - Design).
    "내장 지도와 연결되지 않아 서드파티 지도 앱에 묶는다"가 사유였다
  - ⚠ 경유를 못 넘기므로 이 둘은 **사용자가 누른 그곳**으로 보낸다(`HandoffSheet.singleTarget`).
    목적지 자리의 거점을 그대로 넘기면 '들르기'를 눌렀는데 숙소로 안내된다
- 미설치 분기: 스토어 설치 페이지로 이동
- 핸드오프 직전 스낵바: "내비에서 '무료도로 우선'을 켜면 국도 중심으로 안내돼요"
- ⚠ 카카오모빌리티 길찾기 REST/내장 SDK는 **원칙적으로 사용 금지** (우리가 내비가 되면 안 됨)
  → **예외 없음** (§3.7 삭제, 2026-09-07). 어떤 화면에서도 호출 경로를 만들지 않는다

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

### 3.7 거점 역진입 — **삭제 (2026-09-07)**

거점을 확정한 직후 고속도로↔국도 소요시간을 1회 비교해 "빠른 길 대신 재밌는 길"을
권하던 절이다. **거점 개념을 없애면서 함께 지웠다** (`compare_routes` Edge Function 포함).

⚠ 이건 **원칙 1(비내비)의 유일한 예외**였다. 이제 길찾기 REST 를 부르는 코드가
  앱에도 서버에도 없다 — 원칙 1은 예외 없이 절대적이다.

### 3.8 별 보기 좋은 밤 — **삭제 (2026-09-07)**

'달 없는 밤 × 전망대·야영장·천문대' 를 곱해 별 보기 좋은 밤을 말하려던 절이다.
만든 건 `moonless`/`eventTitle` **한 줄 문장뿐**이었고, 그건 CO-06·MY-02에서
분위기만 말하고 **어떤 장소로도 이어지지 않았다.** 곱의 한쪽(장소)이 끝내 구현되지 않았다.

천문연 데이터가 남는 곳은 **레이더 일몰 카드(§3.1 타이밍 가중치)** 하나다 —
거기서는 전망 좋은 곳이라는 장소와 일몰 −60~−20분이라는 시점이 함께 있어
'들르라'고 말할 수 있다. 그게 이 데이터를 온전히 쓰는 형태다.

⚠ 남겨 둔 것: `sun_moon` 테이블(일몰 카드가 쓴다) · `astro_events` 테이블 ·
  `moonless()`·`night_sky_on()` 함수 · `fetch:astro`. **앱에서 읽는 곳은 없다.**
  되살릴 거면 절을 다시 쓰고 승인받는다 — 지운 이유가 '데이터가 없어서'가 아니라
  '장소로 이어지지 않아서'였다는 걸 잊지 말 것.

## 4. 외부 API·키 목록

| 서비스 | 용도 | 발급처 | 소비 위치 |
|---|---|---|---|
| TourAPI (국문관광정보/사진/연관관광지/고캠핑/두루누비/수요강도) | 스팟 수집 | data.go.kr | pipeline + Edge Fn |
| 전국전통시장표준데이터 | 장날 | data.go.kr | pipeline |
| 천문연 출몰시각 | 일몰 (레이더 일몰 카드). **전망 스팟이 있는 격자만** 채운다 (약 40칸). 월출·월몰·박명은 받아만 둔다 | data.go.kr | pipeline |
| 티맵 URL 스킴 (`tmap://route`) | 핸드오프 | SK open API 앱 연동 | 앱 |
| ~~카카오내비 SDK~~ | ~~핸드오프~~ (2026-09-09 티맵으로 교체, 검증 뒤 삭제) | developers.kakao.com | 앱 |
| 카카오맵 **네이티브 SDK v2** | 지도 표시 (kakao_map_sdk) | developers.kakao.com | 앱 — **네이티브 앱 키**, 내비와 공용 |
| 천문연 천문현상 정보 | 유성우·월식·슈퍼문 — **앱에서 읽는 곳 없음** (§3.8 삭제). 테이블만 남겨둔다 | data.go.kr (B090041) | pipeline |
| 한국관광 데이터랩 (검색·방문 변화율) | CO-01 "조용히 뜨는 길" | datalab.visitkorea.or.kr | pipeline |
| Supabase | BaaS | supabase.com | 전체 |

⚠ 기상청 단기예보(우천 시 실내 가중치)는 **스코프 아웃** — 기획문서 §10에 있으나 MVP에서 쓰지 않는다.

환경변수: `SUPABASE_URL/ANON_KEY`(앱), `TOURAPI_KEY, DATA_GO_KR_KEY`(pipeline/EdgeFn),
`KAKAO_NATIVE_APP_KEY`(앱). 서비스 키는 앱에 절대 포함 금지.

⚠ data.go.kr 인증키는 **계정 단위**다. 출몰시각·천문현상·전통시장은 API마다 활용신청만
따로 하면 같은 `DATA_GO_KR_KEY`를 쓴다 — 키가 늘지 않는다.

## 5. 화면 ↔ 구현 매핑 (기획 문서 화면ID 기준)

| 화면ID | 라우트 | 핵심 의존성 |
|---|---|---|
| ON 온보딩 | `/onboarding` | 최초 1회. 권한은 요청만, 강제 없음 |
| CO-01 홈 | `/` | courses, events, markets(오늘 장날), 데이터랩 변화율. **뷰 모드 2개** |
| SR 검색 | `/search` | 스팟·코스 텍스트 검색 + 필터. 모달, 탭바 덮음 |
| CO-07 국도 선택 | `/routes` | routes 51행, drivable 구분 |
| CO-02 코스 상세 | `/course/:id` | course.geom + 경로변 spots, RouteBadge |
| CO-03 스팟 상세 | `/spot/:id` | spot + spot_links + 확신도 문구. **마을/스팟 통합** |
| HND 핸드오프 시트 | (모달) | 티맵 · 애플 지도 딥링크 (kakao_flutter_sdk_navi 는 검증 뒤 삭제) |
| DR-00 위치 권한 | (`/radar` 인라인) | 앱 사용 중 허용만 |
| DR-01 레이더 | `/radar` | discover_nearby RPC, 위치 스트림, rec 로깅 |
| DR-02 발견 카드 | (레이더 내 전면 카드) | 점수 상위 1건, 액션: 핸드오프/찜/passed |
| DR-03 몰아보기 | (레이더 내 오버레이) | passed 스팟 2~4건 |
| ~~DR-05 동승자~~ | **삭제됨 (2026-09-03)** | `discover_ahead` RPC는 레이더가 물려받았다 |
| DR-06 백그라운드 | (권한 유도 + OS 알림) | 백그라운드 위치 + 로컬 알림. **iOS 기준** (2026-08-29) |
| MY-02 여행기 | `/trip/:id` | trips/stops/photos, 공유 카드 |
| MY-01/03 마이 | `/my` | saves(like/passed), 국도 수집 진행률, 설정 |

## 6. 스코프 아웃 (구현 금지·보류)

- 금지: 턴바이턴/ETA/경로재탐색, 별점·후기, 예약·결제, 절대량 인기 랭킹
  - 길찾기 REST **전면 금지, 예외 없음** (§3.7 삭제, 2026-09-07)
- 2차 보류: STT 음성 응답, **동승자 모드 실시간 동기화**(단말 2대 — MVP는 1대 모드 전환),
  국도 색칠 지도 렌더링(진행률 숫자까지만 MVP), 숏폼 영상, 찜 재소환 추천,
  마을 상세 분리(CO-03 통합으로 대체), 기상청 우천 가중치
- **MVP로 승격됨** (2026-08-26 결정): 거점 역진입(§3.7), DR-05 동승자 모드,
  DR-06 백그라운드 근접 알림, CO-01 급상승 실데이터화

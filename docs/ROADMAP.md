# ROADMAP.md — P의 여행 개발 로드맵 v2

Claude Code 세션 단위로 쪼갠 태스크. 위에서 아래로 진행하고, 완료 시 `[x]` 커밋.
각 마일스톤은 "데모 가능한 상태"로 끝나야 한다.

> **v2 변경 (2026-08-26)**: 거점 역진입 · DR-05 동승자 · DR-06 백그라운드 알림 ·
> 급상승 실데이터가 MVP로 승격. 프로토타입 HTML을 직접 생성하기로 결정(M0.3 신설).
> 총 11~15일 → **약 19~20일**.

---

## 병렬 트랙 — 오늘 바로 신청 (코드로 우회 불가, 리드타임 있음)

M1이 전부 여기 걸려 있다. M0 코딩과 **동시에** 진행할 것.

- [ ] data.go.kr: TourAPI (국문관광정보 GW / 관광사진 / 연관관광지 / 고캠핑 / 두루누비)
- [ ] data.go.kr: 전국전통시장표준데이터
- [ ] data.go.kr: 한국천문연구원 출몰시각
- [ ] 한국관광 데이터랩 — 검색·방문 변화율 (CO-01 "조용히 뜨는 길")
- [ ] developers.kakao.com: 앱 등록 → 네이티브 앱 키, 카카오맵·내비·로그인 활성화
- [ ] developers.kakaomobility.com: 길찾기 REST 키 (**§3.7 전용**, Edge Function에만 투입)
- [ ] Supabase 프로젝트 생성

---

## M-1. 스펙 정합화 (반나절) — 코드 이전에

문서 4개 사이의 충돌을 먼저 닫는다. 안 닫으면 M2~M3에서 매번 멈춘다.

- [x] SCREENS.md: **CO-03 스팟 상세** 절 추가 (마을/스팟 통합 확정)
- [x] SCREENS.md: **CO-06b 국도 제안** 절 추가 + CO-06에 `/base` 역진입 경로 반영
- [x] SCREENS.md: **DR-05 동승자 모드 / DR-06 백그라운드 알림** 절 추가
- [x] TECH_SPEC §2: trust_score 배점표, detour_min 정의, exit_geom/exit_frac,
      markets 끝자리 정규화, trips status·nullable, saves CHECK 제약
- [x] TECH_SPEC §3.1: 진출로 역산 타이밍 + 정차 시 heading 필터 해제
- [x] TECH_SPEC §3.2: 장날 판정식 수정 (10·20·30 → 0 정규화, 월말 오판 검수)
- [x] TECH_SPEC §3.3 / §3.7: 길찾기 REST 예외 명문화 + 티맵 보조, §3.4 권한 2단계
- [x] TECH_SPEC §4·§5·§6: 데이터랩·길찾기 키 추가, 라우트 표 갱신, 스코프 재정리
- [x] CLAUDE.md: 원칙 1 예외 조항, 원칙 3 외부 링크 허용 명시, strings.dart 규약
- [ ] **검토 요청** — 위 신규 절 4개(CO-03 / CO-06b / DR-05 / DR-06)는 초안. 승인 후 확정

## M0. 프로젝트 셋업 (반나절)

- [x] git init + 모노레포: `app/`(Flutter) · `pipeline/`(Node+TS) · `supabase/`
- [x] **CLAUDE.md를 리포 루트로 이동**
- [x] Flutter 버전 결정 → **핀 고정** (go_router 17.5.0 / flutter_riverpod 3.3.2). Flutter 업그레이드는 보류
- [x] Riverpod + go_router 3탭 셸 + 라우트 테이블 전체 선언 + 뷰 모드 글로벌 상태
- [x] `.env.example` + `dart_defines.example.json` + `core/env.dart`, `.gitignore` 정비
- [x] Supabase CLI 설치 + `supabase init` + **brrrp 격리**(project_id·포트·파이프라인 가드)
- [ ] Supabase 프로젝트 연결 (`supabase link --project-ref <ref>`) + PostGIS 활성화  ← **ref 필요**

## M0.3. 디자인 시안 (1~1.5일) ★신규 — 프로토타입 HTML을 직접 만든다

산출물: `docs/P의여행_프로토타입_v2.html` (SCREENS.md·CLAUDE.md가 이 파일명을 참조).
Figma는 만들지 않는다 — CSS 변수 → `theme.dart` 1:1 이식이 목적.

- [x] mobbin MCP로 레퍼런스 수집 (다크 레이더 화면, 바텀 오버레이 카드, 지도 상세)
- [x] ui-ux-pro-max 스킬로 팔레트·타이포·간격·모션 확정
      (CLAUDE.md 색 6개를 **고정 시드**로, 나머지 토큰을 파생)
- [x] 프로토타입 HTML — **시연 플로우 7화면 우선**:
      CO-01 / CO-07 / CO-02 / CO-06 / DR-01 / DR-02 / MY-02
- [x] 공통 컴포넌트 6종: RouteBadge(sm/md/lg) · 탭바 · 토스트 · 스팟카드 · 확신도 문구 · 하트
- [x] `core/theme.dart` 이식 (RouteBadge 위젯은 M2에서 화면과 함께)
- [x] Pretendard 폰트 5종(400~800) + OFL 라이선스 번들
- [x] `core/strings.dart` — SCREENS.md 고정 카피 전량 상수화

## M0.5. 관통 스파이크 (반나절) — 버릴 코드 전제

여기서 막히면 M1 시작 전에 설계를 고친다.

- [ ] 카카오맵에 하드코딩 LineString 1개 + 핀 3개 렌더 → **지도 플러그인 확정**
      (`kakao_map_plugin` 0.4.0은 0.x 커뮤니티 패키지 — 대안 검토 포함)
- [ ] `NaviApi.navigate(viaList:)` **실기기** 1회 호출 → 핸드오프 가능 여부 확정
- [ ] geolocator 스트림 + heading/speed 실측 → §3.1 방향 필터 임계값 조정

## M1. 데이터 파이프라인 (2.5일) ★데모 품질의 8할

- [ ] **데이터 실측 스파이크 (0.5일)** — 착수 전 필수:
      · 데이터랩이 **2개 시점**을 주는가 (안 주면 "조용히 뜨는 길" 변화율 불가)
      · 연관관광지 API가 기준연월 파라미터를 받는가 (안 받으면 "차량 유입 급증" 불가)
      · 데이터랩 입도(시군구) ↔ 코스/스팟 매칭 방법 확정
      · TourAPI 쿼터·실제 응답 스키마 (문서와 다른 필드 주의)
      → 결과에 따라 아래 두 태스크의 구현 방식이 갈린다. **결과 먼저 공유**
- [ ] 마이그레이션: routes/courses/spots/spot_links/markets/events/profiles/saves/trips/* (TECH_SPEC §2)
- [ ] `build-routes.ts`: 국도 51선 메타 시드 + 7번 국도 삼척–강릉 LineString
- [ ] `fetch-tourapi.ts`: 위치기반관광정보 — 경로변 5km 버퍼 수집
      → type 매핑, **trust_score 배점표 적용**, exit_geom/exit_frac/detour_min 계산
- [ ] 확장 병합: 관광사진, 행사(events), 고캠핑, 두루누비
- [ ] 연관 관광지 → spot_links
- [ ] `fetch-markets.ts`: 전통시장표준데이터 → markets (**끝자리 정규화 필수**, 북평장 3·8일 확인)
- [ ] 천문연 일몰 시각 일 단위 캐시 (좌표 격자별)
- [ ] `fetch-datalab.ts`: 검색·방문 변화율 → 코스/스팟 급상승 지표
- [ ] 검수 스크립트: 스팟 수 / trust 분포 / 장날 판정(월말 포함) / 진출점 거리 리포트

## M2. 발견 탭 (3.5일)

- [ ] ON 온보딩 3장 (SCREENS.md §ON) — 권한은 요청만, 건너뛰기 허용
- [x] CO-01 홈: 뷰 모드 2개(한 곳씩/훑어보기), 국도 레일, 큐레이션 3축. 급상승은 실데이터 대기 중이라 섹션 숨김
- [x] CO-07 국도 선택: 51선 그리드, 남북/동서 탭, drivable 구분
- [x] SR 검색: 별도 모달 화면(흰 배경·리스트·토글 없음), 최근 검색, 필터 한 줄
- [x] CO-02 코스 상세: 경로 미리보기(SDK 미사용), 거점 배너, 뷰 모드별 발견 표시, 출발 CTA
- [x] CO-03 스팟 상세: 사진/영업/확신도 문구/전화 원탭/spot_links/네이버 후기 링크
- [ ] CO-06 거점 설정: 카카오 장소검색 + 지도 핀 → trips(draft).base_*
- [ ] **`/base` 역진입 + CO-06b 국도 제안 모달** + Edge Function `compare_routes` (§3.7)
- [ ] HND 핸드오프 시트 UI (실호출은 M3 — CO-02 CTA가 이미 필요로 함)
- [ ] saves(like) 저장/해제 + 마이 탭 찜 목록 뼈대

## M3. 레이더 (6일) ★킬러 데모

- [ ] **데모 모드(7번 국도 mock 주행) 먼저** — 없으면 남은 5일 내내 실외로 나가야 함
- [ ] DR-00 위치 권한 플로우("앱 사용 중") + geolocator 스트림
- [ ] DR-01 레이더 UI: 동심원 3링 + 스윕 + 블립 + 거점 칩 + 기록 칩
- [ ] `discover_nearby` RPC (PostGIS 반경+방향+타이밍+trust 게이트)
- [ ] **진출로 역산** (exit_frac 기반, 3~7분 구간에서만 카드)
- [ ] DR-02 근접 카드: 장날 문구 자동 생성, 검증 배지, 액션 3종
- [ ] 중복 억제 쿨다운(타입 연속 금지, 30분 2회)
- [ ] DR-03 몰아보기 카드 (정차 감지 3분)
- [ ] 핸드오프 실호출: 카카오내비(viaList/단건) + **티맵 딥링크** + 미설치 분기
- [ ] GPS 로깅: trip draft→active 전환, trip_points 적재
- [ ] 맵매칭: 노선 스냅 50m → 노선별 주행 km
- [ ] **DR-05 동승자 모드**: `discover_ahead` RPC(반경 20km, 게이트 미적용) + 카드 덱 스와이프
- [ ] **DR-06 백그라운드 알림**: 2단계 옵트인 화면 + 백그라운드 위치 + 로컬 알림 +
      발신 조건(장날·일몰·임박만) + 빈도 제한 + 40분 무이동 자동 종료. **Android 우선**

## M4. 여행기 + 마이 (3일)

- [ ] trip 종료 → 여행기 생성: 경로/타임라인(visited·passed·skunked)/통계
- [ ] "계획에 없던 밥" 스탯 — 코스 발견 목록과 대조 계산 (trip_stops만으론 안 나옴)
- [ ] photo_manager 사진 매칭: 시간창 → EXIF GPS or 시각 보간 → stop 귀속
- [ ] MY-02 화면: EP 넘버링, 타임라인, 사진 스트립, "하루 더?" 한 줄
- [ ] 공유 카드: RepaintBoundary 캡처 + 시작·끝 300m 절단 + share_plus + 딥링크
- [ ] MY-01/03: 국도 51선 진행률, 찜/스쳐간 발견, 여행기 리스트, 설정(데모 모드 토글)
- [ ] 카카오 로그인 (Supabase Auth) — 게스트 모드 허용

## M5. 폴리시 & 데모 준비 (1.5일)

- [ ] TTS: 근접 카드 낭독, 무응답 15초 → 자동 찜
- [ ] 알림 톤·문구 최종 검수 (**재촉 금지 원칙 체크리스트** 전수)
- [ ] 시연 리허설: 홈→국도→코스→거점 핀→출발→[시뮬 주행]→장날 카드→들르기→
      스쳐감→여행 종료→여행기→공유→마이 진행률
- [ ] 빌드: Android APK (심사용). iOS TestFlight는 여유 있을 때

---

## 리스크 조기 검증 (M0.5~M1 중, 순서 무관)

- [ ] 카카오내비 viaList 실기기 테스트 (에뮬레이터 불가) — **가장 먼저**
- [ ] 데이터랩·연관관광지 2시점 확보 가능 여부 — M1 스파이크에 포함
- [ ] photo_manager iOS 권한(limited access) 동작 확인
- [ ] DR-06 Android 포그라운드 서비스 배터리·킬 동작 확인
- [ ] 7번 국도 데모 구간 실주행 1회 (가능하면) — 발견 타이밍 체감 조정

## 데모 컷라인 (시간 부족 시 버리는 순서)

1. TTS → 2. 온보딩 → 3. DR-06 백그라운드 알림 → 4. 몰아보기 카드 →
5. DR-05 동승자 모드 → 6. 사진 시각 보간(EXIF GPS만) → 7. CO-06b 국도 제안

**절대 못 버림**: 레이더 + 장날 카드, 내비 핸드오프, 여행기 생성, 거점 핀

> ⚠ 3·5·7번은 이번에 MVP로 승격된 항목이다. 마감일이 확정되면 컷라인을 다시 조정할 것.

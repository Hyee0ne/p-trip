# CLAUDE.md — P의 여행

> 이 파일은 Claude Code가 모든 세션에서 참조하는 프로젝트 지침이다.
> 상세 스펙은 `docs/TECH_SPEC.md`, 작업 순서는 `docs/ROADMAP.md` 참조.

## 프로젝트 한 줄 정의

**P의 여행** — 국도 위의 우연한 발견을 설계하는 '발견 레이더' 모바일 앱.
핵심 카피: "지나치기엔 아까운 것들이, 길마다 있어요."
2026 관광데이터 활용 공모전 출품작. 한국관광공사 OpenAPI 활용 필수.

## 제품 원칙 → 코드 금지사항 (절대 위반 금지)

이 앱은 **내비게이션이 아니고, 숙소 앱도 아니고, 후기 앱도 아니다.**
아래는 기획 원칙이 코드 레벨에서 갖는 의미다. 기능 요청이 이걸 어기면 구현하지 말고 지적할 것.

1. **비내비**: 턴바이턴 안내, 경로 재탐색, ETA 계산·표시 코드를 절대 작성하지 않는다.
   길안내는 카카오내비 핸드오프(SDK 호출)로만. "경로 이탈" 판정·알림 로직 금지.
   - **유일한 예외 (2026-08-26 승인)**: 거점 역진입 제안(TECH_SPEC §3.7).
     거점 확정 직후 **1회**, Edge Function 뒤에서 길찾기 REST로 고속도로↔국도 소요시간을 비교한다.
     이건 안내가 아니라 "빠른 길 대신 재밌는 길로 갈 이유"의 설득 근거다.
     구조적 방어: 앱 번들에 길찾기 키 금지 / 레이더(DR-*) 코드에서 import 금지 /
     결과를 ETA·도착시각으로 환산 금지 / 이동 중 재조회 금지.
     이 예외를 다른 화면으로 확장하자는 요청은 거절하고 되물을 것.
2. **레이더는 경로가 아니라 현재 위치 기준**: 발견 쿼리는 항상 현 위치+진행 방향 반경.
   선택한 코스에서 벗어나도 아무 일도 일어나지 않아야 한다.
3. **비평가**: 별점·후기·랭킹 필드를 스키마에 만들지 않는다.
   신뢰는 데이터 완성도(신뢰도 게이트)와 이동 흔적(연관 관광지)으로만.
   절대량 인기 정렬 금지 — 큐레이션은 변화율(급상승)과 흔적 기준.
   - 외부 후기로 나가는 **링크**는 허용(CO-03 "네이버 후기 보기"). 막지 않는 게 정책이다.
     단 후기 내용·점수를 가져오거나 저장하지 않는다 — 링크를 열어줄 뿐.
4. **비중개**: 예약·결제 플로우 금지. 숙소는 스팟 정보+외부 링크까지만.
   거점은 위치 좌표 입력값일 뿐이다.
5. **로그인 없음** (2026-08-29): 찜·여행기는 기기 안에 둔다. 로그인 화면을 만들지 않는다.
   서버 스키마와 RLS는 남겨둔다 — 계정이 생기는 날 올려 동기화한다.
6. **재촉 금지 UX**: 카운트다운 타이머, "빨리 결정" 류 문구 금지.
   지나친 발견은 조용히 '스쳐간 발견'으로 적립.

## 기술 스택 (확정)

- **앱**: Flutter (Dart), 상태관리 Riverpod, 라우팅 go_router
- **백엔드**: Supabase (Postgres + PostGIS, Auth, Storage, Edge Functions)
- **데이터 파이프라인**: Node.js 스크립트 (TourAPI 수집 → Supabase 적재, 로컬/cron 실행)
- **지도**: kakao_map_sdk (카카오맵 **네이티브** SDK v2 래퍼). 2026-08-29 확정.
  WebView 기반 kakao_map_plugin에서 갈아탔다 — 노선 폴리라인을 여러 개 얹어야 해서
  네이티브 렌더링이 필요하다. **네이티브 앱 키**를 쓰고, 내비 핸드오프와 같은 키다.
  iOS 13.0+ / Android minSdk 23
- **주요 패키지**: geolocator(위치), kakao_flutter_sdk_navi(내비 핸드오프),
  flutter_tts(음성), photo_manager(사진 메타데이터), share_plus(여행기 공유),
  flutter_local_notifications(DR-06 백그라운드 근접 알림)
- ⚠ 버전 제약: 로컬 Dart 3.11.5 기준. flutter_riverpod 3.4+/go_router 18+ 는 Dart 3.12 요구 —
  `flutter upgrade` 하거나 go_router 17.5.0 / flutter_riverpod 3.3.2 로 핀 고정할 것.

## 리포 구조

```
p-trip/
├── CLAUDE.md
├── docs/                  # SCREENS.md(화면 정의), TECH_SPEC.md, ROADMAP.md, 기획문서
│                          # + P의여행_프로토타입_v2.html (비주얼 기준, M0.3에서 생성)
├── app/                   # Flutter 앱
│   └── lib/
│       ├── core/          # 테마, 상수, 유틸
│       ├── data/          # 모델, repository, supabase client
│       ├── features/
│       │   ├── discover/  # 탭1 발견 (홈/국도선택/코스/거점)
│       │   ├── radar/     # 탭2 레이더 (로깅/근접카드/핸드오프)
│       │   └── my/        # 탭3 마이 (찜/여행기/설정)
│       └── main.dart
├── pipeline/              # Node 데이터 수집 스크립트
│   ├── fetch-tourapi.ts   # 관광공사 API → spots
│   ├── fetch-markets.ts   # 전통시장 표준데이터 → 장날
│   └── build-routes.ts    # 국도 노선 GeoJSON 생성
└── supabase/              # 마이그레이션, Edge Functions
```

## 컨벤션

- 언어: UI 문구는 한국어. 코드 식별자·주석은 영어.
- UI 문구는 기획 카피를 그대로 쓴다. 임의로 다시 쓰지 말 것.
  (예: "지나치기엔 아까운 것들이, 길마다 있어요" / "스쳐간 발견" / "오늘 밤 거점")
- **서체 (2026-08-27 확정) — 달릴 땐 고딕, 돌아보면 명조**
  - 이동 중에 읽는 모든 화면 = **Pretendard(고딕)**. 홈·국도·코스·스팟·거점·레이더·발견 카드 전부.
    운전 중 가독성은 안전 문제라 예외 없음. 발견 카드는 본문 15.5px 이상, 터치 영역 56pt.
  - **명조(나눔명조)는 여행기(MY-02)와 공유 카드에만.** 앉아서 읽는 화면이라 감성이 우선.
  - 두 서체가 "달리는 중 / 돌아보는 중"을 나눈다. 이 경계를 넘지 말 것.
- **UI 언어 = 「전면 카드 + 훑어보기 토글」** (2026-08-27 확정) — 시안 `docs/P의여행_시안_C보완.html`.
  - **한 곳씩**: 사진이 화면을 채우는 전면 카드 + 원형 액션 3개. 감성과 운전 중 조작을 동시에
  - **훑어보기**: 2열 그리드 + 검색창 + 필터 칩 **한 줄(오늘만·가까운 곳·[필터])**
  - **검색**: 별도 모달 화면. 흰 배경 + 리스트 행 + 토글 없음 — 훑어보기와 반드시 구분되게
  - 서체는 전부 Pretendard(고딕). 명조 안 씀
  - **컨셉을 위한 UI를 새로 만들지 않는다.** 점수 패널·좌표 표기·수집 칸·표지판 색면·시간대 팔레트는
    전부 "기능을 더하다 감성이 사라졌다"는 이유로 폐기됐다. 감성은 **사진·여백·문장**에서 온다
  - 정보를 늘리기 전에 덜어낼 것부터 찾는다. 필터는 한 줄, 카드 보조설명은 한 줄
- **고정 카피는 `core/strings.dart` 단일 소스.** SCREENS.md에 " "로 적힌 문구는 상수로만 참조하고
  위젯에 직접 문자열을 쓰지 않는다 (임의 수정 방지).
- 디자인 토큰은 `core/theme.dart` 단일 소스. 프로토타입 HTML의 CSS 변수를 그대로 이식:
  route blue `#1D4ED8`, field green `#3E7C4F`, market red `#C2452D`,
  sun `#E8A13D`, night `#0D1117`, bg `#F4F5F1`.
  시그니처 = 국도 표지판 파란 타원 뱃지 (RouteBadge 위젯).
- 커밋: conventional commits (`feat:`, `fix:`, `data:`, `docs:`). 한 커밋 = 한 관심사.
- API 키는 절대 커밋 금지. `.env` + `--dart-define`, TourAPI 키는 Edge Function 뒤로.
- **⚠ Supabase는 `brrrp` 프로젝트와 섞지 않는다** (2026-08-27). 같은 사람이 두 프로젝트를 만진다.
  - `supabase link`를 **인자 없이 실행 금지**. 반드시 `--project-ref <ref>` 명시
  - `project_id = "p-trip"`, 로컬 포트 55321~55329 (기본 54321 대역에서 이동)
  - 파이프라인에 오조준 가드가 있다 — `SUPABASE_URL`의 ref와 `SUPABASE_EXPECTED_REF`가
    다르면 실행을 거부한다. 검증: `cd pipeline && npm run guard`
  - 자세한 규칙은 `supabase/README.md`

## 빌드 주의사항

- **시뮬레이터 ↔ 실기기 빌드를 번갈아 할 땐 사이에 `flutter clean`.**
  `objective_c.framework`(네이티브 에셋)가 시뮬레이터용 x86_64 슬라이스를 품은 채
  기기 빌드로 넘어가 설치가 거부된다 (`invalid signature`).
  증상: `Failed to verify code signature ... 0xe8008014`
- 화면 확인용 주입 — `--dart-define=START_AT=/radar` (시작 화면),
  `--dart-define=AUTO_CARD=false` (레이더 발견 카드 자동 노출 끄기),
  `--dart-define=SHEET_AT=expanded` (CO-07 바텀시트를 펼친 채 시작),
  `--dart-define=FAKE_LOCATION=37.5245,129.1143` (위치 고정. 있으면 geolocator를 아예 안 부른다).
  `--dart-define=DRIVE_SCALE=10` (모의 주행 배속. 기본 20이면 데모 코스 65km가 약 3분),
  `--dart-define=START_MODE=browse` (홈을 훑어보기로 시작).
  시연 리허설에도 쓴다.
- 시뮬레이터 위치는 `xcrun simctl location <sim> set 37.5245,129.1143`로 넣는다.
  권한 팝업은 `xcrun simctl privacy <sim> grant location com.ptrip.roadtrip2026`으로 미리 준다.
  이러면 FAKE_LOCATION 없이 **실제 geolocator 경로**를 확인할 수 있다.
- **실기기 배포는 release로.** iOS 14+에서 debug 빌드는 Flutter 툴이 붙어 있어야만 뜬다
  (홈 화면에서 열면 "debug mode Flutter apps can only be launched from Flutter tooling" 안내가 뜬다).
  ```bash
  flutter build ios --release $(dart-defines)
  xcrun devicectl device install app --device <udid> "$PWD/build/ios/iphoneos/Runner.app"
  xcrun devicectl device process launch --terminate-existing --device <udid> com.ptrip.roadtrip2026
  ```
  ⚠ `flutter install --use-application-binary`는 멀쩡히 있는 `.app`을 "does not exist"라고 거부한다.
  ⚠ `flutter run -d <기기>`는 **`iproxy` 포트 포워딩이 깨져서 못 붙는다.**
- **실기기 Dart 로그는 잡히지 않는다.** release 빌드는 `flutter logs`·`devicectl --console` 둘 다
  아무것도 안 준다. 원인 좁히기는 **같은 코드를 시뮬레이터에서 돌리고**
  `xcrun simctl spawn <sim> log stream --predicate 'processImagePath CONTAINS "Runner"'`로 본다.
  시스템 프레임워크(CoreAudio·TextToSpeech·TCC) 동작이 그대로 찍혀서 Dart 로그보다 나을 때가 많다.
- **화면 작업은 스크린샷으로 확인하기 전까지 완료가 아니다.**
  `flutter analyze`와 위젯 테스트는 레이아웃 깨짐을 전혀 못 잡는다.
  `xcrun simctl io <sim> screenshot`으로 눈으로 볼 것.

## 자주 쓰는 명령

```bash
cd app && flutter run                 # 앱 실행
cd app && flutter analyze             # 린트 (커밋 전 필수)
cd pipeline && npm run fetch:spots    # TourAPI 수집
cd pipeline && npm run fetch:markets  # 장날 데이터 수집
supabase db push                      # 마이그레이션 적용
```

## 데모 기준 데이터

공모전 데모는 **7번 국도 삼척–강릉 구간**으로 고정한다.
실존 스팟: 북평 5일장(3·8일), 추암 촛대바위, 어달마을, 묵호등대.
전국 커버를 가정한 코드를 짜되, 시드 데이터는 이 구간부터 채운다.

## Claude Code 작업 수칙

- 작업 시작 전 `docs/ROADMAP.md`에서 현재 마일스톤 확인, 완료 시 체크 표시 커밋.
- 큰 기능은 계획 먼저 제시 → 승인 후 구현.
- 스키마 변경은 반드시 마이그레이션 파일로 (직접 DB 수정 금지).
- 목업 데이터로 때우지 말 것 — 파이프라인이 준비 안 됐으면 그 작업을 먼저 제안.
- 제품 원칙(위 5개)과 충돌하는 요청은 구현 전에 반드시 되물을 것.
- 화면을 구현할 땐 `docs/SCREENS.md`의 해당 절이 단일 기준이다. 거기 없는 화면은 먼저 절을 쓰고 승인받을 것.

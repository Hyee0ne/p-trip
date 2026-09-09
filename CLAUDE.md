# CLAUDE.md — P의 여행

> 이 파일은 Claude Code가 모든 세션에서 참조하는 프로젝트 지침이다.
> 상세 스펙은 `docs/TECH_SPEC.md`, 작업 순서는 `docs/ROADMAP.md` 참조.

## 프로젝트 한 줄 정의

**P의 여행** — 국도 위의 우연한 발견을 설계하는 '발견 레이더' 모바일 앱.
핵심 카피: "지나치기엔 아까운 것들이, 길마다 있어요."
2026 관광데이터 활용 공모전 출품작. 한국관광공사 OpenAPI 활용 필수.

**⚠ 출시가 우선이다 (2026-08-30 결정).** 공모전은 그 결과물로 낸다.
"데모니까 이만하면 됐다"로 좁혀 잡지 말 것 — 전국 사용자가 쓰는 앱을 만들고 있다.
판단이 갈릴 때는 **출시 기준**이 답이다.

## 제품 원칙 → 코드 금지사항 (절대 위반 금지)

이 앱은 **내비게이션이 아니고, 숙소 앱도 아니고, 후기 앱도 아니다.**
아래는 기획 원칙이 코드 레벨에서 갖는 의미다. 기능 요청이 이걸 어기면 구현하지 말고 지적할 것.

1. **비내비**: 턴바이턴 안내, 경로 재탐색, ETA 계산·표시 코드를 절대 작성하지 않는다.
   길안내는 티맵 핸드오프(URL 스킴)로만. "경로 이탈" 판정·알림 로직 금지.
   - ~~카카오내비 SDK~~ → **티맵 (2026-09-09).** 카카오내비는 안내 중 새 목적지를 거절해 「들르기」가
     막혔다. 티맵은 안내 중에도 경로를 바꾼다 (실기기 확인). 카카오내비 코드·SDK 는 지웠다.
   - ~~유일한 예외: 거점 역진입 제안(§3.7)~~ → **예외 없음 (2026-09-07).**
     거점 개념을 없애면서 그 예외를 쓰던 유일한 코드(`compare_routes` Edge Function)도 지웠다.
     **이제 길찾기 REST를 부르는 코드가 앱에도 서버에도 없다.** 원칙 1은 예외 없이 절대적이다.
     다시 부르자는 요청은 거절하고 되물을 것.
   - 발견 카드의 「여기서 약 N km」(2026-09-09)는 **기기 안에서 잰 직선거리**다. 분·도착 시각으로
     환산하지 않는다 — 그건 ETA다. 갱신도 안 한다 — 줄어드는 숫자는 카운트다운이다 (원칙 6).
2. **레이더는 경로가 아니라 현재 위치 기준**: 발견 쿼리는 항상 현 위치+진행 방향 반경.
   선택한 코스에서 벗어나도 아무 일도 일어나지 않아야 한다.
3. **비평가**: 별점·후기·랭킹 필드를 스키마에 만들지 않는다.
   신뢰는 데이터 완성도(신뢰도 게이트)와 이동 흔적(연관 관광지)으로만.
   큐레이션은 **변화율(급상승)과 흔적**이 우선이다.
   - **정렬에 한해 절대 순위를 보조로 허용한다** (2026-09-04 개정).
     ~~절대량 인기 정렬 금지~~ → 변화율은 **두 시점**이 필요한데 개발계정 한도로
     한 시점만 겨우 받는다. 그 탓에 두 시점이 갖춰진 노선이 7번 하나뿐이었고
     전국 어디를 달려도 큐레이션 한 줄이 안 나왔다.
     ⚠ **변화가 있으면 변화가 이긴다.** 절대 순위는 변화를 못 재는 곳만 채운다 —
       두 시점이 차면 저절로 원래 설계로 수렴한다 (`rising_spots`).
   - ⚠ **근거가 다르면 문구도 달라야 한다.** 절대 순위로 뽑힌 길에
     '요즘 이 길에 발길이 늘었어요'를 붙이면 거짓말이다 — 그 길은 '요즘 더' 도는 게 아니다.
     `routeNotePopular = '이 길로 다녀간 사람이 많아요'` 를 따로 쓴다.
   - ⚠ **별점·후기는 여전히 없다.** 이번에 바뀐 건 정렬 근거뿐이다.
     스키마에 점수 칸을 만들자는 요청은 전과 같이 거절하고 되물을 것.
   - 외부 후기로 나가는 **링크**는 허용(CO-03 "네이버 후기 보기"). 막지 않는 게 정책이다.
     단 후기 내용·점수를 가져오거나 저장하지 않는다 — 링크를 열어줄 뿐.
4. **비중개**: 예약·결제 플로우 금지. 숙소는 스팟 정보+외부 링크까지만.
   - ~~거점은 위치 좌표 입력값일 뿐이다~~ → **거점 개념 자체를 없앴다 (2026-09-07).**
     '오늘 밤 거점'(CO-06), 지도 핀 찍기, 숙소 후보 목록, 거점 역진입 제안(§3.7)을 전부 지웠다.
     잘 곳을 묻는 화면이 있으면 결국 숙소 앱으로 읽힌다 — 이 앱은 **길**을 고르는 앱이다.
     ⚠ 딸려 나간 것: 카카오 장소검색·길찾기 Edge Function 둘 다 삭제 →
       **카카오로 좌표가 나가는 경로가 없어졌다** (위치정보 문의에도 그대로 쓴다).
5. **로그인 없음** (2026-08-29): 찜·여행기는 기기 안에 둔다. 로그인 화면을 만들지 않는다.
   서버 스키마와 RLS는 남겨둔다 — 계정이 생기는 날 올려 동기화한다.
6. **재촉 금지 UX**: 카운트다운 타이머, "빨리 결정" 류 문구 금지.
   - ~~지나친 발견은 조용히 '스쳐간 발견'으로 적립~~ → **폐기 (2026-09-07).**
     담은 적 없는 목록이 계속 불어나 정작 찜을 밀어냈다. **담는 건 사용자만 한다** —
     지나친 곳은 그냥 지나간다. 안 담는 것도 재촉이 아니라, 원칙 자체는 그대로다.
     `SaveKind.passed` · `StopKind.passed` · DR-03 몰아보기는 전부 지웠다.
     ⚠ 옛 기기에 남은 `passed` 기록은 **불러올 때 버린다** — `visited`로 흘러가면
       지나치기만 한 곳이 '들른 곳'이 된다.

## 기술 스택 (확정)

- **앱**: Flutter (Dart), 상태관리 Riverpod, 라우팅 go_router
- **백엔드**: Supabase (Postgres + PostGIS, Auth, Storage, Edge Functions)
- **데이터 파이프라인**: Node.js 스크립트 (TourAPI 수집 → Supabase 적재, 로컬/cron 실행)
- **지도**: **Apple MapKit** (apple_maps_flutter). 2026-09-09 카카오맵(kakao_map_sdk)에서 교체.
  키가 없고 타일 요청이 Apple 밖으로 안 나간다 — 카카오 SDK·키는 앱에서 전부 지웠다
  (내비는 티맵 URL 스킴). 노선 폴리라인은 흰 밑선 + 파란 선 두 겹. 위젯 테스트(macOS)에선
  지도 자리에 '준비 중' 문구가 뜬다 — 가짜 지도를 그리지 않는다.
  iOS 13.0+ / Android minSdk 23
- **주요 패키지**: geolocator(위치), url_launcher 티맵 URL 스킴(내비 핸드오프),
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
- **서체 — 앱 전체가 Pretendard(고딕) 하나** (2026-08-29 확정)
  - 이동 중에 읽는 모든 화면 = **Pretendard(고딕)**. 홈·국도·코스·스팟·거점·레이더·발견 카드 전부.
    운전 중 가독성은 안전 문제라 예외 없음. 발견 카드는 본문 15.5px 이상, 터치 영역 56pt.
  - ~~명조(나눔명조)는 여행기(MY-02)와 공유 카드에만~~ → **폐기 (2026-08-29).**
    여행기·공유 카드도 **Pretendard(고딕)로 간다.** 아래 「UI 언어」 항목과 어긋나 있던 걸 정리했다.
    감성은 서체가 아니라 사진·여백·문장에서 온다 — 이 프로젝트가 계속 지켜온 쪽이다.
  - 즉 **앱 전체가 Pretendard 하나다.** 서체로 화면을 나누지 않는다.
- **UI 언어 = 「지도책 + 전면 카드」** (2026-08-30 개정)
  - **홈은 지도다.** 목적지가 아니라 **길**을 고르는 게 이 앱의 진입 문법이다.
    길 → 방향 → 출발. 정보는 **가면서** 나온다 (참고작 풍향중의 "모르고 간다")
  - ~~훑어보기 토글~~ → **폐기**. 스토리 덱·그리드·뷰 토글을 지웠다.
    출발 전에 다 보여주면 달리는 일이 '확인하러 가는 일'이 되고, 그게 내비 느낌의 원인이었다
  - ⚠ **큐레이션의 양이 아니라 시점이 문제다.** 지우지 말고 **뒤로 밀 것.**
    큐레이션은 홈의 섹션이 아니라 **노선 행의 한 줄**로 붙인다
  - ⚠ 리스크 최소화와 미리 아는 것은 **다르다**. "아홉 곳이 있다"는 안심을 주면서
    "그게 뭔지"는 안 말할 수 있다. **개수는 보여주고 목록은 감춘다**
  - **전면 카드**는 남는다 — 레이더 발견 카드(DR-02)의 문법이다
  - (구) 시안 `docs/P의여행_시안_C보완.html` — 홈 부분은 더 이상 기준이 아니다.
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
- ⚠ **`dart format`은 반드시 `--line-length=100`.** 그냥 부르면 80칸으로 재감싸서
  손대지도 않은 파일 수백 줄이 바뀌고 `curly_braces_in_flow_control_structures` 린트가 뜬다.
  검증: `dart format --line-length=100 --output=none --set-exit-if-changed lib` 가 조용해야 정상.
- ⚠ **파일을 문자열 치환으로 고칠 때 들여쓰기를 눈으로 세지 말 것.** 이 리포는 4칸이고
  읽기 도구가 들여쓰기를 덧붙여 보여줘서 6칸으로 착각하기 쉽다. 원문에서 정규식으로 읽어 쓸 것.
- 커밋: conventional commits (`feat:`, `fix:`, `data:`, `docs:`). 한 커밋 = 한 관심사.
- API 키는 절대 커밋 금지. `.env` + `--dart-define`, TourAPI 키는 Edge Function 뒤로.
- **⚠ Supabase는 `brrrp` 프로젝트와 섞지 않는다** (2026-08-27). 같은 사람이 두 프로젝트를 만진다.
  - `supabase link`를 **인자 없이 실행 금지**. 반드시 `--project-ref <ref>` 명시
  - `project_id = "p-trip"`, 로컬 포트 55321~55329 (기본 54321 대역에서 이동)
  - 파이프라인에 오조준 가드가 있다 — `SUPABASE_URL`의 ref와 `SUPABASE_EXPECTED_REF`가
    다르면 실행을 거부한다. 검증: `cd pipeline && npm run guard`
  - 자세한 규칙은 `supabase/README.md`

## 플랫폼

- **iOS 전용이다** (2026-08-29 확정). 시연도 공모전 제출도 iOS.
  Android는 **취급하지 않는다** — APK 빌드·에뮬레이터 확인·플레이스토어를 작업 목록에 넣지 말 것.
  `android/` 디렉터리와 코드의 Android 분기는 남겨두되(포팅 여지), 그걸 위해 시간을 쓰지 않는다.

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
  `--dart-define=DEPART_AT=7` (그 노선의 「길 떠나기」 시트를 열고 시작).
  ⚠ **zsh는 `$VAR`를 단어 분리하지 않는다.** `--dart-define`들을 변수에 모아
    `$DEF`로 넘기면 통째로 한 인자가 되어 **일부만 먹는다** — 조용히 픽스처로 떨어진다.
    `$(cat defs.txt)`처럼 명령 치환으로 넘길 것.
  시연 리허설에도 쓴다.
- 시뮬레이터 위치는 `xcrun simctl location <sim> set 37.5245,129.1143`로 넣는다.
  권한 팝업은 `xcrun simctl privacy <sim> grant location com.ricecookey.pjourney`으로 미리 준다.
  이러면 FAKE_LOCATION 없이 **실제 geolocator 경로**를 확인할 수 있다.
- **실기기 배포는 release로.** iOS 14+에서 debug 빌드는 Flutter 툴이 붙어 있어야만 뜬다
  (홈 화면에서 열면 "debug mode Flutter apps can only be launched from Flutter tooling" 안내가 뜬다).
  ```bash
  flutter build ios --release $(dart-defines)
  xcrun devicectl device install app --device <udid> "$PWD/build/ios/iphoneos/Runner.app"
  xcrun devicectl device process launch --terminate-existing --device <udid> com.ricecookey.pjourney
  ```
  ⚠ `flutter install --use-application-binary`는 멀쩡히 있는 `.app`을 "does not exist"라고 거부한다.
  ⚠ **`This provisioning profile cannot be installed on this device` (0xe8008012)** —
    기기가 팀에 등록 안 된 게 아니라 **로컬에 캐시된 옛 프로파일**을 Xcode가 갱신 없이 쓴 것이다
    (팀을 `2Q5557H9T4`로 바꾼 2026-08-30 뒤로 두 번 겪었다). Xcode에 그 팀 계정이 없어서
    `flutter build ios`는 새 프로파일을 못 받는다. 해법: 옛 프로파일 파일을 치우고
    (`~/Library/Developer/Xcode/UserData/Provisioning Profiles/`, `embedded.mobileprovision`의 UUID)
    **기기를 대상으로 지정해** API 키로 한 번 서명하면 `iOS Team Provisioning Profile: com.ricecookey.pjourney`가
    새로 생기고, 그 뒤로는 `flutter build ios`가 그걸 쓴다.
    ```bash
    xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos \
      -destination 'platform=iOS,id=<devicectl identifier>' SYMROOT="$PWD/build/ios" OBJROOT="$PWD/build/ios" \
      -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
      -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_7U29A76MBG.p8 \
      -authenticationKeyID 7U29A76MBG -authenticationKeyIssuerID ea714c32-bf27-4e6f-b4cd-cadb3b7a3908 build
    # 결과물은 build/ios/Release-iphoneos/Runner.app (dart-define은 직전 flutter build 의 Generated.xcconfig 를 쓴다)
    ```
  ⚠ 설치·실행은 **아이폰 잠금이 풀려 있어야** 한다 (`kAMDMobileImageMounterDeviceLocked`).
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

## 데이터 범위

**목표는 전국이다.** 지금 적재된 건 7번 국도 삼척–강릉 회랑뿐이고(스팟 625건, 코스 1개),
이건 **출시 전에 채워야 할 빚**이지 완성된 상태가 아니다.

- 파이프라인이 **시군구 3개와 손으로 찍은 회랑 좌표**에 박혀 있다. 전국으로 여는 게 M6의 1번이다
- 회랑 판정은 손좌표가 아니라 **`routes.geom` 51선**으로 해야 한다 — 이미 적재돼 있다
- 코스도 하드코딩 목록이다. 노선을 구간으로 잘라 자동 생성해야 한다
- 전국 수집은 **data.go.kr 운영계정**이 있어야 한다 (개발계정은 하루 1,000건 남짓)

**심사 시연 시나리오**는 7번 국도 삼척–강릉으로 잡는다 —
북평민속오일장(3·8일), 추암 촛대바위, 어달해변. 이건 **시연 동선**이지 제품 범위가 아니다.

## 출시 (M6)

- **데모 모드는 개발 빌드에만.** `Env.demoAvailable` — release에서는 `DEMO_BUILD=true`를
  명시해야 열린다. 출시 앱 설정에 '가짜로 달리는 모드'가 있으면 안 된다.
  ⚠ 실기기 테스트용 빌드에는 `--dart-define=DEMO_BUILD=true`를 **꼭 넣을 것** —
    안 넣으면 서서 확인할 방법이 없다 (실주행만 돈다)
- **로그인은 붙이지 않는다** (2026-08-30 재확인, 원칙 5 유지).
  ⚠ 그래서 **폰을 바꾸거나 앱을 지우면 찜·여행기가 사라진다.** 알고 가는 선택이다 —
    나중에 백업을 붙이더라도 계정을 넣지는 않는다
- 스토어 준비물: 개인정보처리방침 · 앱 아이콘 · 스크린샷 · 지원 URL · 연령등급 ·
  **백그라운드 위치 심사 문구**(가장 까다롭다)

## Claude Code 작업 수칙

- 작업 시작 전 `docs/ROADMAP.md`에서 현재 마일스톤 확인, 완료 시 체크 표시 커밋.
- 큰 기능은 계획 먼저 제시 → 승인 후 구현.
- 스키마 변경은 반드시 마이그레이션 파일로 (직접 DB 수정 금지).
- 목업 데이터로 때우지 말 것 — 파이프라인이 준비 안 됐으면 그 작업을 먼저 제안.
- 제품 원칙(위 5개)과 충돌하는 요청은 구현 전에 반드시 되물을 것.
- 화면을 구현할 땐 `docs/SCREENS.md`의 해당 절이 단일 기준이다. 거기 없는 화면은 먼저 절을 쓰고 승인받을 것.

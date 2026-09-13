import 'dart:math' as math;

/// P의 여행 고정 카피 — 단일 소스.
///
/// 출처는 `docs/SCREENS.md`. 그 문서에서 " "로 적힌 문구는 **고정 문구**이고
/// 임의로 다시 쓸 수 없다. 위젯에 문자열을 직접 쓰지 말고 여기서만 참조할 것.
/// 문구를 바꾸려면 SCREENS.md를 먼저 고치고 승인받는다.
class S {
  S._();

  // ── 브랜드 ──
  static const appName = 'P의 여행';
  static const heroLine1 = '지나치기엔 아까운 것들이,';
  static const heroLine2 = '길마다 있어요.';
  static const heroSub = '오늘만 서는 장, 40분 뒤의 일몰, 이름 없는 물회 골목 — 놓치기 전에 레이더가 알려드려요.';

  // ── 탭바 (SCREENS.md §0.2) ──
  static const tabDiscover = '발견';
  static const tabRadar = '레이더';
  static const tabMy = '마이';

  // ── 뷰 모드 (§0.1) ──
  static const viewOneByOne = '한 곳씩';
  static const viewBrowse = '훑어보기';

  // ── 온보딩 (§ON) ──
  // ── ON 온보딩 3장 (A안, 2026-09-09) ──
  // ⚠ 국도 번호 상식('홀수는 남북…')과 권한 카드 두 장을 뺐다. 사용법이 아니었고, 권한은 여기서 묻지 않는다.
  static const onboardSub = '네비가 못 알려주는 길 위의 발견';
  static const onboardSkip = '건너뛰기';
  static const onboardNext = '다음';
  static const onboardStart = '길 고르러 가기';
  static const onboardHowTitle = '목적지는 안 정해요.\n길만 골라요.';
  static const onboardStep1 = '길을 고르고';
  static const onboardStep1Sub = '지도에서 지금 탈 수 있는 국도';
  static const onboardStep2 = '방향만 정하고';
  static const onboardStep2Sub = '어디까지 갈지는 안 물어요';
  static const onboardStep3 = '달리면 됩니다';
  static const onboardStep3Sub = '발견은 가면서 나와요';
  static const onboardStep3Pill = '레이더';
  static const onboardAheadTitle = '앞쪽에 뭐가 있는지,\n카드 한 장으로 알려드려요';
  static const onboardExample = '예시';
  static const onboardExampleSpot = '북평 5일장';
  static const onboardExampleBody = '3·8일에만 서는 장이라, 다음 장은 5일 뒤예요.';

  // ⚠ 권한 예고 줄('위치는 출발할 때, 알림은 처음 달린 뒤에 물어요')은 뺐다 (2026-09-13).
  //   온보딩은 권한을 묻지 않고, 그 이유는 물을 때(DR-01 진입) 말한다.

  // 3장 보강 (2026-09-13) — 카드 세 동작의 이름과, 내비 위에서 어떻게 닿는지 두 줄.
  static const onboardActSkip = '넘기기';
  static const onboardActSave = '찜';
  static const onboardAheadVoice = '내비를 켜둔 채여도 소리로 먼저 알려드려요';
  static const onboardAheadTrace = '놓쳐도 알림에 남아요. 눌러서 되돌아갈 수 있어요';

  // ── CO-01 홈 섹션 ──
  static const secRoutes = '국도부터 고르기';
  static const secRising = '조용히 뜨는 길';
  static const secRisingSub = '지난주보다 검색이 는 곳';
  static const secTracks = '요즘 차들이 몰래 가는 곳';
  static const secTracksSub = '이동 흔적 기준';
  static const secToday = '오늘만 열리는 발견';
  static const secTodaySub = '장날 레이더';

  /// 오늘 장날이 없을 때 §CO-01 섹션 헤더 대체.
  static const secThisWeek = '이번 주에 열리는 발견';
  static const homeEmpty = '오늘은 조용하네요. 국도부터 골라볼까요?';

  // ── SR 검색 ──
  static const searchHint = '장날, 물회, 등대…';
  static const searchRecent = '최근 검색';
  static const searchClear = '지우기';
  static const searchSuggest = '이런 건 어때요';
  static String searchEmpty(String q) => '\'$q\'로는 못 찾았어요';

  // ── 필터 (§0.2 — 밖에 두는 건 둘뿐) ──
  static const filterToday = '오늘만';
  static const filterNear = '가까운 곳';
  static const filterMore = '필터';

  // ── CO-07 국도 선택 ──
  static const routesTitle = '국도 51선';
  static const routesSub = '남북 27 · 동서 24';

  /// 노선 한 줄 (CO-01 재설계). ⚠ 절대량 인기를 말하지 않는다 (원칙 3).
  static String routeNoteMarket(int n) => n == 1 ? '오늘 이 길에 장이 서요' : '오늘 이 길에 장이 $n곳 서요';

  /// 두 시점 사이 순위가 **실제로 오른** 길 (연관관광지 202603 → 202606).
  /// ⚠ '관심'이라 하지 않는다 — 재는 건 관심이 아니라 **발걸음**이다.
  ///   연관관광지는 다녀간 기록이라, '관심'으로 말하면 데이터보다 약해지고
  ///   동시에 인기·평가 쪽 언어로 흘러간다 (원칙 3).
  /// ⚠ '돈다'고 하지 않는다 (2026-09-07 교체) — 국도 앱에서 **우회**로 읽힌다.
  static const routeNoteRising = '요즘 이 길에 발길이 늘었어요';

  /// 변화를 못 쟀지만 흔적이 많은 길 (2026-09-04).
  /// ⚠ '늘었다'고 하지 않는다 — 절대 순위로 뽑힌 길은 요즘 발길이 느는 게 아니다.
  /// ⚠ 별점이 아니라 **이동 흔적**이다. '다녀간' 이 그걸 그대로 말한다.
  static const routeNotePopular = '이 길로 다녀간 사람이 많아요';

  /// 코스 진입 — 주인공이 아니라 안전망이라는 게 문장에 있어야 한다.

  // ── CO-08 길 떠나기 ──
  static String routeNumber(int id) => '$id번 국도';
  static const departWhichWay = '여기서 어느 쪽으로 갈까요?';
  static const departNorth = '북쪽으로';
  static const departSouth = '남쪽으로';
  static const departEast = '동쪽으로';
  static const departWest = '서쪽으로';

  /// ⚠ 목적지를 묻지 않는다는 걸 화면이 직접 말한다 — 내비와 다른 점이라서.
  static const departNoDestination = '목적지는 정하지 않아요. 가다 마음에 들면 멈추면 돼요.';
  static const departNeedLocation = '위치를 알아야 이 길의 어느 쪽인지 알 수 있어요.';
  static const departNoPath = '이쪽으로는 이어진 길을 못 찾았어요. 반대쪽으로 가볼까요?';

  static const routeUndrivable = '통일을 기다리는 길';
  static const routeNoCourse = '이 길의 코스를 준비하고 있어요';

  /// 좌표가 없어 내비로 넘길 수 없을 때. 지어내지 않고 그렇다고 말한다.
  static const handoffNoCoords = '이곳은 위치 정보가 없어 길안내로 넘길 수 없어요';
  static const handoffNoMap = '지도 앱을 열지 못했어요';

  // CO-07 지도 + 바텀시트 (SCREENS.md CO-07, 2026-08-29 확정)
  static const routesNearTitle = '여기서 탈 수 있는 길';
  static const routesAllCta = '51선 전체';
  static const routesSecNear = '내 주변';

  /// ⚠ '전체'로 쓰면 남북/동서 필터 칩의 '전체'와 한 화면에서 같은 말이 두 번 나온다.
  static const routesSecAll = '그 밖의 길';
  static const routesNearEmpty = '여긴 국도에서 좀 떨어져 있어요';

  /// ⚠ 위와 구분해서 쓴다. 데이터가 없는 지역에 '국도가 없다'고 하면 거짓말이다.
  static const routesNoCoverage = '아직 이 지역 길을 모아두지 못했어요';
  static const routesLocOff = '위치를 켜면 여기서 탈 수 있는 길을 알려드려요';
  static const routesLocCta = '위치 켜기';
  static const routesLocFinding = '위치를 찾는 중이에요';
  static const routesMapPending = '지도는 준비 중이에요';
  static String routesNearCount(int n) => '$n개';

  // ── CO-02 코스 상세 ──
  static const courseDiscoveries = '경로 위의 발견';
  static const courseOrder = '지나는 순서';
  static const courseStart = '이 코스로 출발';
  static String kmAway(double km) =>
      km < 1 ? '${(km * 1000).round()}m' : '${km.toStringAsFixed(1)}km';

  // ── CO-03 스팟 상세 ──
  static const trustNotice = '영업·개장 정보는 공공데이터 기준이에요. 방문 전 확인을 권해요';
  static const trustCall = '전화';
  static const trustReviews = '네이버 후기 보기';
  static const spotShallow = '정보가 아직 얕은 곳이에요';
  static const spotNextVisits = '들른 차들은 다음에';
  static const spotNextVisitsSub = '이동 흔적 기준';
  static const spotNavigate = '길 안내';
  static const spotBook = '예약';

  // ── HND 핸드오프 ──
  /// 출발 시트 제목. **길 이름으로 말한다** — 앱 이름이 아니다 (2026-09-09).
  ///   '카카오내비로 안내를 시작해요'는 카카오를 고른 것처럼 읽혔고, 애플 지도가 뒤로 밀렸다.
  static String handoffTitleRoute(int routeId) => '$routeId번 국도로 안내를 시작해요';

  /// 노선 번호를 모를 때의 예비 제목 (골든·테스트). 실제 출발은 언제나 번호가 있다.
  static const handoffTitle = '길 안내를 시작해요';

  /// ⚠ 티맵 URL 스킴엔 경로 옵션 파라미터가 없다 — 사용자가 티맵에서 고른다 (2026-09-09).
  ///   카카오내비 때는 코드로 '무료도로 우선'을 줬다.
  static const handoffFreeRoad = '티맵에서 경로 옵션을 \'무료도로\'로 바꾸면 국도 중심으로 안내돼요';

  /// 주 내비. ⚠ 카카오내비 → 티맵 (2026-09-09): 카카오내비는 안내 중 새 목적지를 거절해
  ///   「들르기」가 막혔다. 티맵은 안내 중에도 경로를 바꾼다 (실기기 확인).
  static const handoffTmap = '티맵';

  /// ⚠ **애플 지도를 지우지 말 것.** 없으면 App Store 심사에서 반려된다
  ///   (2026-09-02, Guideline 4 - Design). SCREENS.md §HND 참조.
  static const handoffApple = '애플 지도';

  /// 경유가 있을 때만 낸다 — 없으면 굳이 할 말이 아니다.
  static String handoffDestOnly(String name) => '경유는 못 넘겨요 · $name만 안내돼요';

  // ── DR-00 권한 ──
  static const permTitle = '레이더가 주변을 살피려면 위치가 필요해요';
  static const permSub = '이동 중에만 사용하고, 기록은 내 기기에 먼저 저장돼요';
  static const permGo = '허용하러 가기';
  static const permLater = '나중에';

  // ── DR-01 레이더 ──
  static const radarScanning = '주변을 살피는 중';

  /// DR-00 — 실주행인데 위치 권한이 없을 때. 막지 않고 이유만 말한다.
  static const radarNeedsLocation = '위치를 켜야 앞에 뭐가 있는지 볼 수 있어요.';
  static const radarOpenSettings = '설정 열기';
  static const radarUseDemo = '데모 모드로 보기';

  /// DR-01 — 그 자리 반경 30km에 **스팟이 하나도 없을 때.**
  ///
  /// ⚠ '지금 근처에 없다'와 반드시 구분한다. 데이터가 다 찬 7번 국도에서 잠깐 조용할 때
  ///   '준비 중'이 뜨면 앱이 미완성으로 보인다 — 그건 거짓말이다.
  /// ⚠ **기한을 암시하지 않는다.** 언제 채워질지 모르는데 '곧'이라고 하면 지키지 못할 약속이다.
  static const radarNotYet = '이 지역은 아직 준비 중이에요';
  static const radarNotYetSub = '길은 있지만 아직 볼 것을 다 모으지 못했어요';

  /// 데이터는 있는데 지금 반경 안에 걸리는 게 없을 때. 위와 다르다.
  static const radarQuiet = '이 근처는 지금 조용해요';

  /// 레이더 하단 버튼. ⚠ '→ 여행기 만들기' 를 뗐다 (2026-09-09) — 마치면 여행기로 가는 건
  ///   동작이지 이름이 아니다. 버튼은 한 가지만 말한다.
  static const radarFinish = '오늘 여행 마치기';

  /// 핸드오프 시트를 건너뛴 이유 — 진입 때 토스트로 (DR-01 진입 ③). 말 안 하면 오류처럼 보인다.
  static String radarNoNavOnRoute(int routeId) => '이미 $routeId번 국도 위라 안내 없이 켰어요';
  static const radarNoNavDemo = '데모 모드라 안내 없이 켰어요';

  /// 「오늘 들른 곳」 자취 (2026-09-09, 시안 A). 기록이지 버튼이 아니다.
  static const radarStopsTitle = '오늘 들른 곳';
  static const radarStopsNext = '다음';

  /// DR-01 ⓪ — 레이더 탭인데 길을 안 골랐을 때 (2026-09-08).
  /// ⚠ 아무것도 돌지 않는다. 버튼 하나가 발견 탭으로 보낸다 — 눌러도 아무 일 없는 화면이 아니다.
  static const radarIdleTitle = '어디로 떠나볼까요?';
  static const radarIdleSub = '레이더는 길을 고르고 출발하면 켜져요';
  static const radarIdleCta = '국도 고르러 가기';

  /// 핸드오프 시트를 안 고르고 내렸을 때 하단 버튼. 시트를 다시 연다.
  /// ⚠ 레이더는 내비 앱을 고른 순간부터 돈다 (2026-09-08). 그전엔 이 버튼이 유일한 길이다.
  static const radarHandoffAgain = '내비로 안내받기';

  static String radarRecording(String route, num km) => '$route ${km}km 기록 중';

  /// 국도를 아직 모를 때. **번호를 지어내지 않는다** — 여행기의 국도는
  /// 나중에 실제 궤적으로 맵매칭한다 (`setRouteKm`).
  static String radarRecordingNoRoute(num km) => '${km}km 기록 중';

  // ── DR-02 발견 카드 ──
  static const cardVerified = '영업정보·사진이 확인된 발견만 알려드려요';
  static const cardVisit = '들르기';
  static const cardSave = '찜해두기';
  static String cardMarketDay(String name) => '오늘이 마침 $name이에요';
  static String cardSunset(String name) => '곧 $name에 해가 져요';

  /// 상황 칩 앞머리(일반형). 거리는 여기 없다 — 카드가 뜨는 순간 레이더가 [cardSituation] 으로 붙인다.
  static const cardNearbyLead = '근처에 있어요';

  /// '여기서 약 2.4km'. 카드가 뜬 순간의 **현 위치↔스팟 직선거리**다. 도로 거리도 소요시간도 아니다.
  /// ⚠ 분으로 바꾸지 않는다 — 그건 도착 예정(ETA)이고 원칙 1이 막는다.
  /// ⚠ 전엔 '국도에서 N분'(detour_min: 노선 최근접점↔스팟 왕복 어림)이었는데,
  ///   운전자 입장에선 어디서부터 N분인지 알 수 없었다 (2026-09-09).
  static String cardFromHere(double km) => '여기서 약 ${distanceLabel(km)}';

  /// 앞머리 + 거리. 거리를 모르면(좌표 없음·위치 없음) 앞머리만 — 없는 숫자를 지어내지 않는다.
  static String cardSituation(String lead, double? km) =>
      km == null ? lead : '$lead · ${cardFromHere(km)}';

  /// 0.73 → '700m' · 2.44 → '2.4km' · 2.0 → '2km' · 12.6 → '13km'. 100m 아래는 '100m' 로 올린다.
  static String distanceLabel(double km) {
    if (km < 0.95) return '${math.max(100, (km * 10).round() * 100)}m';
    if (km < 10) {
      final v = (km * 10).round() / 10;
      return v == v.roundToDouble() ? '${v.round()}km' : '${v}km';
    }
    return '${km.round()}km';
  }

  static String nextMarketDay(int days) => '다음 장은 $days일 뒤예요';
  static String nextVisited(String spot) => '들른 차들은 다음에 $spot로 갔어요';

  // ── DR-07 들른 뒤, 다음 (2026-09-13) ──
  static const nextTitle = '여기서 앞쪽으로';
  static String nextSub(int n) => '10km 안 · $n곳';
  static const nextEmpty = '앞쪽 10km엔 아직 없어요.\n그냥 길로 돌아가도 돼요.';
  static String nextBackToRoute(int id) => '그냥 $id번 국도로 돌아가기';
  static const nextNotifTitle = '앞쪽 10km에 갈 만한 곳이 있어요';
  static String nextNotifBody(int n) => '여기서 앞쪽으로 $n곳 · 눌러서 보기';

  // ── MY-03 발견 간격 (2026-09-13) ──
  static const gapRow = '발견 간격';
  static const gapOften = '자주';
  static const gapNormal = '보통';
  static const gapRare = '가끔';
  static const gapNote = '카드 사이 최소 간격 · 자주 1km/1분 30초 · 보통 2km/3분 · 가끔 4km/6분';

  // ── DR-08 길 바꾸기 (2026-09-13) ──
  static const switchTitle = '길을 바꿀까요?';
  static const switchSub = '여기서 탈 수 있는 국도예요. 여행과 기록은 그대로 이어져요.';
  static const switchCurrent = '지금 이 길';
  static const switchEmpty = '근처에 갈아탈 국도가 없어요';
  static String departSwitchNote(int cur, int next) => '$cur번 여행 중이에요. $next번으로 갈아타도 여행과 기록은 이어져요.';
  static String switchedTo(int id) => '$id번 국도로 갈아탔어요';
  static String tripSwitched(int id, int prevId, int prevKm) =>
      '$id번 국도로 갈아탐 · $prevId번 ${prevKm}km';

  // ── DR-06 백그라운드 알림 ──
  static const bgStopped = '레이더를 접어뒀어요';
  static const bgDemoNote = '데모 모드에선 앱을 내리면 주행이 멈춰요 — 알림은 실제 주행에서 나갑니다.';

  // ── MY-02 여행기 ──
  static String episode(int n, String date) => 'EP.$n — $date';
  static String tripTitle(String route) => '$route에서 생긴 일';
  static const tripSub = '오늘의 여행이 한 편의 이야기가 됐어요';
  static const tripTimeline = '지나온 시간';
  static const statVisited = '들른 발견';
  static const statSkunked = '허탕';
  static const statUnplannedMeal = '계획에 없던 밥';

  /// MY-02 대표 사진 고르기 (2026-09-07).
  ///
  /// ⚠ **내가 찍은 사진만** 후보다. 관광공사 사진을 내 여행의 얼굴로 쓰지 않는다 —
  ///   그건 여행기가 아니라 카탈로그다 (MY-02가 사진 스트립에서 지켜온 규칙과 같다).

  /// MY-02 대표 사진 행 (2026-09-09) — 사진첩 어디서든 고른다. 시스템 선택기라 권한 팝업 없음.
  static const coverTitle = '대표 사진';
  static const coverAuto = '아직 안 골랐어요 · 첫 들른 곳 사진으로 보여요';
  static const coverChosen = '내가 고른 사진';
  static const coverPick = '사진첩에서 고르기';
  static const toastCover = '대표 사진을 바꿨어요';
  static const tripShare = '여행기 공유하기';
  static const tripSharing = '카드 만드는 중…';
  static const tripEmpty = '이번엔 그냥 달린 날 — 길만 남은 것도 여행이에요';

  // ── MY-01 마이 ──
  static const collectionTitle = '대한민국 국도 51선';
  static String collectionNth(int n) => '지금 $n선째';
  static const savedTab = '찜';

  /// ⚠ '레이더가 담아준다'고 하지 않는다 — 자동 적립을 없앴다 (2026-09-07). 담는 건 사용자뿐이다.
  static const savedEmpty = '아직 담긴 발견이 없어요. 마음에 드는 곳을 ❤️로 담아보세요.';
  static const tripsTitle = '여행기';

  /// ⚠ 섹션 라벨만 덩그러니 두지 않는다 — 빈 화면에 아무 말이 없으면 고장으로 읽힌다.
  static const tripsEmpty = '아직 여행기가 없어요. 레이더를 켜고 한 번 달리면 여기 쌓여요.';

  // ── 일몰 발견 (SCREENS.md DR-02 2·3번) ──
  // ⚠ 문구는 DR-02 규정 그대로다. 임의로 다시 쓰지 말 것.
  static String sunsetTitle(String name) => '곧 $name에 해가 져요';
  static String sunsetNote(int minLeft) => '일몰 $minLeft분 전';

  // ── 데이터 출처 (MY-01/03 설정) ──
  // ⚠ 공공누리는 유형과 무관하게 **출처표시가 의무**다. 스토어 설명이 아니라
  //   콘텐츠를 쓰는 앱 안에서 밝혀야 한다. 이 목록을 지우지 말 것.
  static const sourcesRow = '데이터 출처';
  static const sourcesIntro = '이 앱은 아래 공공데이터를 이용합니다.';
  static const sourcesNote = '사진과 소개글의 저작권은 각 제공기관에 있습니다.';

  /// ⚠ 카카오 → Apple 지도 · 티맵 (2026-09-09). 앱에 카카오가 남지 않았다.
  static const sourcesMapRow = '지도';
  static const sourcesMapOrg = 'Apple 지도';
  static const sourcesNavRow = '길 안내 · 앱으로 넘겨요';
  static const sourcesNavOrg = '티맵';

  /// (제공기관, 데이터셋). 파이프라인이 **실제로 부르는 것**만 적는다 —
  /// 안 쓰는 출처를 적으면 그것도 거짓말이다.
  ///
  /// ⚠ **한국관광공사만 `출처: ©` 형식이다.** 공사 가이드라인이 그렇게 요구한다
  ///   ([O] `출처: ©한국관광공사` / [X] `TourAPI` — API 서비스명 단독 표기 금지).
  ///   다른 기관은 각자 공공누리 기준을 따르므로 임의로 ©를 붙이지 않는다.
  /// ⚠ 로고 이미지는 쓰지 않는다 — 공사는 **텍스트 표기만** 허용한다.
  static const sources = <({String org, String what})>[
    (org: '출처: ©한국관광공사', what: '국문 관광정보 · 관광지 연관정보'),
    (org: '한국천문연구원', what: '출몰시각 정보'),
    (org: '소상공인시장진흥공단', what: '전국전통시장표준데이터'),
    (org: '국토교통부', what: '일반국도 도로중심선'),
  ];

  /// MY-01 여행기 행을 왼쪽으로 밀어 지운다 (2026-09-09). 되돌리기는 토스트 한 번.
  static const tripDeleteAction = '삭제';
  static const tripDeleted = '여행기를 지웠어요';
  static const tripUndo = '되돌리기';

  /// MY-03 — **기본 음성일 때만** 보이는 행. iOS 고품질 음성은 앱이 못 받고 사용자가
  ///   설정에서 내려받는다. 앱이 열어줄 수 있는 설정 화면도 없다 — 경로만 알려준다.
  static const voiceBetterRow = '더 자연스러운 목소리 받기';
  static const voiceBetterWhy = '지금은 기본 음성이에요. 고품질 음성을 내려받으면 낭독이 훨씬 자연스러워요.';

  /// 고품질 음성을 받는 길. 앱이 그 화면을 열어줄 수 없어 글로 안내한다.
  /// ⚠ **iOS 26 에서 「콘텐츠 말하기」가 「읽기 및 말하기」로 바뀌었다.** 시뮬레이터 런타임의
  ///   설정 앱 한국어 리소스(`ReadAndSpeakSettings.strings`)로 확인했다 (2026-09-09).
  ///   품질 이름도 iOS 그대로: 「유나(기본 품질)」「유나(고품질)」「유나(프리미엄)」,
  ///   버튼은 「프리미엄 음성 다운로드」. 지어내지 않는다 — 다르면 못 찾는다.
  static List<String> voiceBetterSteps(int iosMajor) => [
    '설정 → 손쉬운 사용',
    iosMajor >= 26 ? '읽기 및 말하기' : '콘텐츠 말하기',
    '음성 → 한국어 → 유나',
    '프리미엄 음성 다운로드',
  ];

  /// 받고 나면 할 일이 없다 — 앱이 제일 좋은 음성을 알아서 고른다 (`Voice.pickVoice`).
  static const voiceBetterAfter = '받고 나면 따로 고를 것 없이 앱이 그 목소리로 읽어요.';

  // ── 토스트 (§0.2 — 단일 스타일, 1.9초) ──
  static const toastSaved = '찜에 담았어요';

  /// MY-03 토글을 켰는데 OS 권한이 이미 거절돼 있을 때. iOS 는 다시 못 묻는다 — 설정 앱으로 보낸다.
  static const toastNotifDenied = '알림이 꺼져 있어요 — 설정에서 켜주세요';

  // ── 공통 예외 (§0.3) ──
  static const errNetwork = '잠시 연결이 고르지 않아요';
  static const errRetry = '다시 시도';
}

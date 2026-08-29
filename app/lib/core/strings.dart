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
  static const onboard2 = '홀수는 남북, 짝수는 동서. 한 자리 국도가 나라의 기본 축이에요. 전부 51개 노선, 14,000km';
  static const onboardLocation = '레이더가 주변을 살피려면요';
  static const onboardPhoto = '여행기에 사진을 자동 정리해드려요';

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
  static const routeUndrivable = '통일을 기다리는 길';
  static const routeNoCourse = '이 길의 코스를 준비하고 있어요';

  /// 좌표가 없어 내비로 넘길 수 없을 때. 지어내지 않고 그렇다고 말한다.
  static const handoffNoCoords = '이곳은 위치 정보가 없어 길안내로 넘길 수 없어요';

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
  static const routesMapFailed = '지도를 불러오지 못했어요';
  static String routesNearCount(int n) => '$n개';

  // ── CO-02 코스 상세 ──
  static const courseDiscoveries = '경로 위의 발견';
  static const courseOrder = '지나는 순서';
  static const courseStart = '이 코스로 출발';
  static const courseStartWithoutBase = '거점 없이도 출발할 수 있어요';

  /// CO-06 보조 버튼. 거점은 선택사항이라 나가는 길이 반드시 있어야 한다.
  static const baseSkipAndStart = '건너뛰고 출발';

  // ── 거점 (CO-06) ──
  static const baseTitle = '오늘 밤 거점';
  static const baseIntro = '거점은 숙소가 아니라 \'위치\'예요. 어디서 예약했든 상관없어요 — 핀 하나만 찍으면 레이더의 기준점이 됩니다.';
  static const baseSearchHint = '예약한 숙소·주소 검색';
  static const basePinOnMap = '지도에서 핀 찍기';
  static const baseCandidates = '종점 근처 참고 후보';
  static const baseCandidatesSub = '정보만 · 예약은 외부';
  static const baseWithout = '거점 없이 출발해도 레이더는 돌아가요.';
  static const baseCta = '이 위치를 오늘 밤 거점으로';
  static const baseNone = '오늘 밤 거점이 아직 없어요';
  static const baseNoneSub = '잘 곳 하나만 정해두면, 가는 길이 자유로워져요';
  static String baseSet(String name) => '오늘 밤 거점: $name';
  static const baseSetSub = '계획 끝. 이제 가는 길은 비워둬도 돼요';
  static const baseConfirmed = '확정됨';
  static const baseToastExternal = '예약은 외부에서 — 여기선 위치만 받아요';
  static const baseToastPickFirst = '거점을 먼저 골라주세요';

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
  static const handoffTitle = '카카오내비로 안내를 시작해요';
  static const handoffFreeRoad = '내비에서 \'무료도로 우선\'을 켜면 국도 중심으로 안내돼요';
  static const handoffKakao = '카카오내비 열기';
  static const handoffTmap = '티맵으로(목적지만)';

  // ── DR-00 권한 ──
  static const permTitle = '레이더가 주변을 살피려면 위치가 필요해요';
  static const permSub = '이동 중에만 사용하고, 기록은 내 기기에 먼저 저장돼요';
  static const permGo = '허용하러 가기';
  static const permLater = '나중에';

  // ── DR-01 레이더 ──
  static const radarScanning = '주변을 살피는 중';
  static const radarNotRoute = '경로를 따라가지 않아요. 지금 내 주변만 봅니다 — 길을 바꿔도, 목적지가 바뀌어도 그대로 작동해요.';
  static const radarSolo = '혼자 운전 중이라면 말로 하세요 — "응, 들를래" / "찜해줘". 대답이 없으면 조용히 찜에 담아둘게요.';
  static const radarFinish = '오늘 여행 마치기 → 여행기 만들기';

  // ── DR-03 몰아보기 (정차 시) ──
  /// ⚠ "되돌아가기" 유도 문구를 쓰지 않는다. 갈지 말지는 사용자가 정한다 (SCREENS DR-03).
  static const catchupTitle = '아까 스쳐간 곳들';
  static const catchupGo = '지금 가기';
  static const catchupKeep = '계속 찜';
  static const catchupDrop = '지우기';
  static String radarRecording(String route, num km) => '\$route \${km}km 기록 중';
  static String baseChipSet(String name) => '오늘 밤 $name — 낮은 마음껏 새어나가세요';
  static const baseChipNone = '오늘 밤 거점 없음 — 그래도 레이더는 돌아가요';

  // ── DR-02 발견 카드 ──
  static const cardVerified = '영업정보·사진이 확인된 발견만 알려드려요';
  static const cardVisit = '들르기';
  static const cardSave = '찜해두기';
  static String cardMarketDay(String name) => '오늘이 마침 $name이에요';
  static String cardSunset(String name) => '곧 $name에 해가 져요';
  static String cardNearby(int min) => '근처에 있어요 · 국도에서 $min분';
  static String nextMarketDay(int days) => '다음 장은 $days일 뒤예요';
  static String nextVisited(String spot) => '들른 차들은 다음에 $spot로 갔어요';

  // ── DR-03 몰아보기 ──
  static const passedTitle = '아까 스쳐간 곳들';

  // ── DR-05 동승자 ──
  static const companionTitle = '동승자 모드';
  static const companionSub = '앞쪽에 뭐가 있는지 대신 봐주세요';
  static const companionBack = '레이더로 돌아가기';
  static const companionEmpty = '이 앞은 잠시 조용해요';
  static String companionNext(String spot) => '다음 정차지 제안: $spot';

  // ── DR-06 백그라운드 알림 ──
  static const bgOptInTitle = '앱을 꺼둬도 알려드릴까요?';
  static const bgOptInSub = '달리는 동안에만 위치를 봅니다. 여행을 마치면 스스로 꺼져요.';
  static const bgOptInYes = '허용하러 가기';
  static const bgOptInNo = '지금은 괜찮아요';
  static const bgStopped = '레이더를 접어뒀어요';

  // ── MY-02 여행기 ──
  static String episode(int n, String date) => 'EP.$n — $date';
  static String tripTitle(String route) => '$route에서 생긴 일';
  static const tripSub = '오늘의 여행이 한 편의 이야기가 됐어요';
  static const tripTimeline = '지나온 시간';
  static const statVisited = '들른 발견';
  static const statPassed = '스쳐간 발견';
  static const statSkunked = '허탕';
  static String photoCaption(int n) => '사진 $n장이 GPS·촬영 시각으로 경로 위에 자동 정리됐어요';
  static String tripFooter(num km) => '국도 수집 +\${km}km · 스쳐간 곳은 찜에 남겨뒀어요';
  static const tripShare = '여행기 공유하기';
  static const tripShareToast = '시작·끝 300m는 가려져요';
  static const oneMoreDay = '이 동네가 좋았다면, 하루 더?';
  static const tripEmpty = '이번엔 그냥 달린 날 — 스쳐간 곳은 다음 핑계예요';
  static const photoDenied = '사진 접근을 허용하면 자동으로 정리해드려요';

  // ── MY-01 마이 ──
  static const collectionTitle = '대한민국 국도 51선';
  static String collectionNth(int n) => '지금 $n선째';
  static const savedTab = '찜';
  static const passedTab = '스쳐간 발견';
  static const savedEmpty = '아직 담긴 발견이 없어요. 레이더가 담아주거나, ❤️로 직접 담아요.';
  static const tripsTitle = '여행기';

  /// ⚠ 섹션 라벨만 덩그러니 두지 않는다 — 빈 화면에 아무 말이 없으면 고장으로 읽힌다.
  static const tripsEmpty = '아직 여행기가 없어요. 레이더를 켜고 한 번 달리면 여기 쌓여요.';

  // ── 토스트 (§0.2 — 단일 스타일, 1.9초) ──
  static const toastSaved = '찜에 담았어요';
  static const toastPassed = '스쳐간 발견에 담아뒀어요';

  // ── 공통 예외 (§0.3) ──
  static const errNetwork = '잠시 연결이 고르지 않아요';
  static const errRetry = '다시 시도';
}

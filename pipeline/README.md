
## 매일 자동 수집 (launchd) — **해제됨 (2026-09-13)**

전국 상세 수집이 끝나(2026-09-12, 운영계정) 사용자 결정으로 launchd 등록을 풀었다
(`bootout` + `disable` + `~/Library/LaunchAgents` 의 plist 삭제. 저장소의 `scripts/` 사본은 남겨 둔다).
⚠ 이 스크립트가 하던 일 중 **수집이 끝나도 남는 것**이 둘 있다 — 필요할 때 손으로 돌린다:
- `npm run fetch:sunset` (DAYS=30) — 일몰 캐시는 앞날 30일치다. 창이 지나면 **일몰 카드·알림이 조용히 사라진다.**
  달에 한 번쯤 돌리면 된다 (천문연 API, 격자 518칸 × 30일, 이미 받은 날은 건너뛴다).
- `npm run fetch:related` — 연관 관광지 두 시점(변화율) 근거. 안 돌리면 큐레이션 한 줄이 그대로 멈춰 있다.
다시 매일로 돌리려면 아래 등록 절차를 그대로.

개발계정은 하루 약 1,000건이라 전국을 받으려면 20일쯤 매일 돌려야 했다.
`scripts/daily-fetch.sh` 를 launchd 가 **00:05 · 09:00 (KST)** 에 부르던 구조다.

```bash
# 등록 (한 번만)
cp pipeline/scripts/com.ricecookey.ptrip.fetch.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ricecookey.ptrip.fetch.plist

# 상태 · 마지막 결과
launchctl print gui/$(id -u)/com.ricecookey.ptrip.fetch | grep -E "state|runs|last exit"
tail -40 pipeline/logs/fetch-$(date '+%Y-%m').log

# 지금 당장 한 번 (스케줄과 무관)
launchctl kickstart -p gui/$(id -u)/com.ricecookey.ptrip.fetch

# 해제
launchctl bootout gui/$(id -u)/com.ricecookey.ptrip.fetch
```

**왜 cron 이 아니라 launchd 인가** — 자정에 맥이 자고 있으면 cron 은 그날을 통째로
건너뛴다. launchd 는 깨어날 때 밀린 작업을 실행한다. 20일을 하루도 안 버리려면 이쪽이다.

⚠ **launchd 는 PATH 를 거의 안 준다.** npm 을 절대경로로 불러도 npm 이 내부에서 `node` 를
PATH 에서 찾다가 죽는다 (`env: node: No such file or directory`). 스크립트가 PATH 를 직접 깐다.
등록만 하고 넘어가면 **매일 조용히 실패한다** — 반드시 `kickstart` 로 한 번 확인할 것.

⚠ 09:00 은 보험이다. 00:05 에 다 받았으면 한도에 걸려 몇 콜 쓰고 바로 멈춘다.

⚠ 자정 리셋은 **관측값**이다 (2026-09-03 21:46 에도 `detailIntro2` 가 소진 상태였다).
   로그에 며칠 쌓이면 실제 리셋 시각이 드러난다 — 어긋나면 plist 의 Hour 를 고친다.

## 기능설명서 대표 사례 캡처 — 2026-09-18 장날 예약 (launchd 1회)

북평민속오일장(3·8일 장)이 「오늘이 마침 …이에요」 카드로 뜨는 실제 화면을 장날 아침에 찍어 기능설명서에 넣는다.
`tools/docs/capture_case.sh`(시뮬레이터 캡처, 임시 주입 후 되돌림) → `tools/docs/fill_feature_sheet.py`(pptx 갱신) → 커밋·푸시.
래퍼는 `tools/docs/refresh_feature_sheet.sh`, 예약은 `tools/docs/com.ricecookey.ptrip.case-capture.plist` (9/18 09:40 KST).

```bash
cp tools/docs/com.ricecookey.ptrip.case-capture.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ricecookey.ptrip.case-capture.plist
launchctl print gui/$(id -u)/com.ricecookey.ptrip.case-capture | grep -E "state|last exit"   # 상태
tail -30 pipeline/logs/capture_case.log                                                      # 결과
launchctl bootout gui/$(id -u)/com.ricecookey.ptrip.case-capture                             # 해제 (돌고 나면)
```
⚠ 맥이 켜져 있어야 한다(잠자기면 깨어날 때 돈다). Supabase 의 장날 판정은 UTC 날짜라 09:00 KST 이후에 돌려야 한다.
⚠ 키노트 PDF 미리보기는 launchd 컨텍스트에서 자동화 권한이 없으면 건너뛴다 — 다음 세션에서 다시 뽑는다.


## 매일 자동 수집 (launchd)

개발계정은 하루 약 1,000건이라 전국을 받으려면 20일쯤 매일 돌려야 한다.
`scripts/daily-fetch.sh` 를 launchd 가 **00:05 · 09:00 (KST)** 에 부른다.

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

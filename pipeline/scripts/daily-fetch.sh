#!/bin/bash
#
# 매일 TourAPI 할당량이 리셋되면 상세를 이어받는다.
#
# ⚠ 반드시 pipeline/ 에서 돌아야 한다 — `lib/supabase.ts` 가 `../.env` 를 상대경로로 읽는다.
# ⚠ launchd 는 PATH 가 거의 비어 있다. node·npm 을 절대경로로 부른다.
#
# 개발계정은 하루 약 1,000건이라 스크립트가 한도에 걸리면 스스로 멈추고
# 받아둔 것까지 저장한다. 다음 날 같은 명령이 이어받는다.
#
# 로그: pipeline/logs/fetch-YYYY-MM.log  (달마다 새 파일이라 알아서 정리된다)

set -uo pipefail

# ⚠ **launchd 는 PATH 를 거의 안 준다.** npm 을 절대경로로 불러도 npm 이 내부에서
#   `node` 를 PATH 에서 찾다가 `env: node: No such file or directory` 로 죽는다.
#   2026-09-03 실제로 그렇게 실패했다 — 확인 안 했으면 20일을 조용히 날렸다.
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

REPO="/Users/hyewon/공모전/trip"
PIPE="$REPO/pipeline"
NPM="/usr/local/bin/npm"
LOGDIR="$PIPE/logs"

mkdir -p "$LOGDIR"
LOG="$LOGDIR/fetch-$(date '+%Y-%m').log"

cd "$PIPE" || { echo "$(date '+%F %T')  ✗ $PIPE 로 못 갔다" >> "$LOG"; exit 1; }

{
  echo ""
  echo "════ $(date '+%F %T %Z') ════"
} >> "$LOG"

# ⚠ 오조준 가드. SUPABASE_URL 이 다른 프로젝트를 가리키면 여기서 멈춘다.
if ! "$NPM" run --silent guard >> "$LOG" 2>&1; then
  echo "  ✗ 가드 실패 — 적재하지 않는다" >> "$LOG"
  exit 1
fi

# ── 1) 스팟 상세 ─────────────────────────────────────────
# detailIntro2 한도(하루 약 1,000건)에 걸리면 스스로 멈추고 받아둔 것까지 저장한다.
"$NPM" run --silent fetch:spots >> "$LOG" 2>&1
CODE=$?

# ── 2) 국도 진출점 ───────────────────────────────────────
# ⚠ **이걸 빼먹으면 하루치를 받고도 레이더에 하나도 안 뜬다.**
#   route_id·detour_min 이 비면 `detour_min <= 10` 필터에 걸린다.
#   2026-09-04 에 실제로 999건이 하루 동안 그렇게 묻혀 있었다.
# ⚠ API 를 쓰지 않는다 — DB 계산이라 한도와 무관하다. 1) 이 실패해도 돈다.
echo "" >> "$LOG"
echo "  ── 진출점 계산 ──" >> "$LOG"
"$NPM" run --silent compute:exits >> "$LOG" 2>&1

# ── 3) 연관 관광지 ───────────────────────────────────────
# ⚠ **다른 오퍼레이션이라 한도가 따로다.** 1) 이 소진돼도 이건 돈다.
#   큐레이션 한 줄('요즘 이 길로 더 도네요')의 근거다.
echo "" >> "$LOG"
echo "  ── 연관 관광지 ──" >> "$LOG"
"$NPM" run --silent fetch:related >> "$LOG" 2>&1

# ── 4) 일몰 시각 ─────────────────────────────────────────
# ⚠ **안 돌리면 어느 날 일몰 카드가 통째로 사라진다.** sun_moon 은 앞날 며칠치를
#   미리 채워두는 캐시라 창이 지나가면 그날 것이 없다. 조용히 안 뜰 뿐 오류가 안 난다.
# ⚠ 격자는 **전망 스팟이 있는 칸만** 만든다 (약 40칸). 이미 받은 (격자, 날짜)는 건너뛰니
#   평소엔 하루치 40콜쯤이다. 천문연 API라 TourAPI 한도와 **무관**하다 — 1) 이 소진돼도 돈다.
# ⚠ 스팟이 늘면 전망 격자도 늘어난다. 그래서 1) 뒤에 둔다.
echo "" >> "$LOG"
echo "  ── 일몰 시각 ──" >> "$LOG"
DAYS=30 "$NPM" run --silent fetch:sunset >> "$LOG" 2>&1

# 오늘 성과를 한 줄로 남긴다. 로그를 끝까지 안 읽어도 보이게.
SAVED=$(grep -oE '✓ spots [0-9,]+건 적재' "$LOG" | tail -1)
EXITS=$(grep -oE '✓ 진출점 [0-9,]+건 계산' "$LOG" | tail -1)
LINKS=$(grep -oE '✓ spot_links [0-9,]+건 적재' "$LOG" | tail -1)
echo "" >> "$LOG"
echo "  [종료 $CODE] ${SAVED:-저장 요약 없음} · ${EXITS:-진출점 없음} · ${LINKS:-링크 없음}" >> "$LOG"
exit $CODE

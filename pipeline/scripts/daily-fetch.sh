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

"$NPM" run --silent fetch:spots >> "$LOG" 2>&1
CODE=$?

# 오늘 성과를 한 줄로 남긴다. 로그를 끝까지 안 읽어도 보이게.
SAVED=$(grep -oE '✓ spots [0-9,]+건 적재' "$LOG" | tail -1)
echo "  [종료 $CODE] ${SAVED:-저장 요약 없음}" >> "$LOG"
exit $CODE

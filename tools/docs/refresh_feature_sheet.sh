#!/bin/zsh
# 대표 사례 캡처(capture_case.sh) → 기능설명서 pptx 갱신 → 커밋·푸시. 2026-09-18 장날 아침 launchd 로 돈다.
# 키노트 PDF 미리보기는 launchd 컨텍스트에서 자동화 권한이 없을 수 있어 실패해도 넘어간다 (다음 세션에서 다시 뽑는다).
set -u
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
REPO=/Users/hyewon/공모전/trip
LOG=$REPO/pipeline/logs/capture_case.log
exec >> "$LOG" 2>&1
echo "════ $(date '+%F %T') refresh_feature_sheet ════"
"$REPO/tools/docs/capture_case.sh"
cd "$REPO" || exit 1
for f in card handoff trail trip spot; do [ -s "docs/screenshots/case/case-$f.png" ] || { echo "missing case-$f.png — abort"; exit 1; }; done
python3 tools/docs/fill_feature_sheet.py /private/tmp/claude-501/-Users-hyewon-----trip/3ed80c01-c87c-48ba-9ebb-47750db0e0c7/scratchpad/shots2 || exit 1
osascript <<'AS' || echo "keynote export skipped"
with timeout of 400 seconds
tell application "Keynote"
  set doc to open POSIX file "/Users/hyewon/공모전/trip/docs/기능설명서_P의여행.pptx"
  export doc to POSIX file "/Users/hyewon/공모전/trip/docs/기능설명서_P의여행_미리보기.pdf" as PDF
  close doc saving no
end tell
end timeout
AS
git add docs/screenshots/case docs/기능설명서_P의여행.pptx docs/기능설명서_P의여행_미리보기.pdf
git commit -q -m "docs(공모전): 기능설명서 대표 사례 — 북평민속오일장 장날 실제 캡처 ($(date '+%Y-%m-%d'))

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>" && git push -q origin main && echo "pushed $(git rev-parse --short HEAD)"
echo "##### refresh done $(date '+%T')"

#!/bin/zsh
# 기능설명서 대표 사례 캡처 — 7번 국도 북평민속오일장 (3·8일 장날).
#   장날 카드 → 들르기(핸드오프 시트) → 「오늘 들른 곳」 자취 → 여행기.
# 시뮬레이터(iPhone 17 Pro Max)에서 임시 주입(커밋 안 함)으로 재현한다. 장날에 돌리면 카드가 「오늘이 마침 …이에요」가 된다.
# 결과: docs/screenshots/case/case-{card,handoff,trail,trip}.png. 그 뒤 fill_feature_sheet.py 가 이 파일을 쓴다.
# 실행: tools/docs/capture_case.sh   (launchd 로 2026-09-18 09:30 KST 예약 — pipeline/README 참조)
set -u
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/development/flutter/bin:$HOME/flutter/bin:$PATH"
REPO=/Users/hyewon/공모전/trip; APP=$REPO/app; OUT=$REPO/docs/screenshots/case
SIM=2A18DFCC-4BA5-4A9B-AC09-0BFA3C1574FA
LOG=$REPO/pipeline/logs/capture_case.log; mkdir -p "$(dirname $LOG)" "$OUT"
exec >> "$LOG" 2>&1
echo "════ $(date '+%F %T') capture_case ════"
cd "$APP" || exit 1
FL=$(command -v flutter || ls $HOME/*/flutter/bin/flutter 2>/dev/null | head -1); [ -z "$FL" ] && { echo "flutter not found"; exit 1; }
git diff --quiet -- lib/features/radar/radar_screen.dart || { echo "radar_screen dirty — abort"; exit 1; }
python3 - <<'PY'
import pathlib
p = pathlib.Path('lib/features/radar/radar_screen.dart'); s = p.read_text()
anchor = "    WidgetsBinding.instance.addObserver(this);\n  }\n"
assert s.count(anchor) == 1
temp = """    WidgetsBinding.instance.addObserver(this);
    // BEGIN TEMP SHOT
    if (const bool.fromEnvironment('SHOT_JOURNEY')) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final fix = await ref.read(currentLocationProvider.future);
        final path = await ref
            .read(discoverRepositoryProvider)
            .routePathAhead(routeId: 7, lat: fix.lat!, lng: fix.lng!, northOrEast: true);
        ref
            .read(startedJourneyProvider.notifier)
            .set(Journey(routeId: 7, routeName: '동해 바닷길', path: path));
        if (mounted) _setRunning(true);
        Discovery? picked;
        Future.delayed(const Duration(seconds: 7), () {
          if (!mounted) return;
          final k = _queueKey(ref.read(driveProvider));
          if (k == null) return;
          final q = ref.read(radarQueueProvider(k)).value ?? const <Discovery>[];
          if (q.isEmpty) return;
          final raw = q.firstWhere((x) => x.spot.name.contains('북평'), orElse: () => q.first);
          picked = applySunset(raw, _sky, DateTime.now());
          _current = picked;
          _currentKm = _kmFromHere(ref.read(driveProvider), picked!.spot);
          _shown.add(picked!.spot.id);
          setState(() => _cardVisible = true);
        });
        Future.delayed(const Duration(seconds: 15), () {
          if (!mounted || picked == null) return;
          final d = picked!;
          HandoffSheet.show(
            context,
            mode: HandoffMode.visit,
            destination: HandoffPlace(d.spot.name, d.spot.lat, d.spot.lng),
          );
          _advance(saved: true);
        });
        Future.delayed(const Duration(seconds: 22), () {
          if (mounted) Navigator.of(context).maybePop();
        });
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) _finish();
        });
      });
    }
    // END TEMP SHOT
  }
"""
p.write_text(s.replace(anchor, temp)); print("patched")
PY
DEFS=$(python3 -c "import json; d=json.load(open('dart_defines.json')); print(' '.join(f'--dart-define={k}={v}' for k,v in d.items()))")
DEFS="$DEFS --dart-define=FAKE_LOCATION=37.46,129.15 --dart-define=DEMO_BUILD=true --dart-define=DIAG=false --dart-define=START_AT=/radar --dart-define=SHOT_JOURNEY=true --dart-define=AUTO_CARD=false --dart-define=DRIVE_SCALE=6"
xcrun simctl boot $SIM 2>/dev/null; sleep 3
xcrun simctl terminate $SIM com.ricecookey.pjourney 2>/dev/null
"$FL" build ios --simulator ${(z)DEFS} 2>&1 | grep -E "✓ Built|Error|error:"
git checkout -- lib/features/radar/radar_screen.dart; echo "reverted: $(grep -c 'TEMP SHOT' lib/features/radar/radar_screen.dart)"
xcrun simctl uninstall $SIM com.ricecookey.pjourney 2>/dev/null
xcrun simctl install $SIM build/ios/iphonesimulator/Runner.app && echo installed
xcrun simctl privacy $SIM grant location com.ricecookey.pjourney 2>/dev/null
xcrun simctl location $SIM set 37.46,129.15 2>/dev/null
xcrun simctl launch $SIM com.ricecookey.pjourney >/dev/null 2>&1
t=0; for pair in 15:card 21:handoff 27:trail 38:trip; do at=${pair%%:*}; name=${pair##*:}; sleep $((at - t)); t=$at; xcrun simctl io $SIM screenshot "$OUT/case-$name.png" >/dev/null 2>&1 && echo "  case-$name t$at"; done
xcrun simctl terminate $SIM com.ricecookey.pjourney 2>/dev/null
# 스팟 상세 (같은 사례) — START_AT 으로 바로 연다. 임시 주입 없음.
DEFS2=$(python3 -c "import json; d=json.load(open('dart_defines.json')); print(' '.join(f'--dart-define={k}={v}' for k,v in d.items()))")
DEFS2="$DEFS2 --dart-define=FAKE_LOCATION=37.46,129.15 --dart-define=DEMO_BUILD=true --dart-define=DIAG=false --dart-define=START_AT=/radar/spot/3f3e6495-9274-4cc2-a23a-6c552bc801bc"
"$FL" build ios --simulator ${(z)DEFS2} 2>&1 | grep -E "✓ Built|Error|error:"
xcrun simctl install $SIM build/ios/iphonesimulator/Runner.app && echo installed spot
xcrun simctl launch $SIM com.ricecookey.pjourney >/dev/null 2>&1
sleep 8; xcrun simctl io $SIM screenshot "$OUT/case-spot.png" >/dev/null 2>&1 && echo "  case-spot t8"
xcrun simctl terminate $SIM com.ricecookey.pjourney 2>/dev/null
python3 - <<'PY'
import json, datetime, pathlib
d = datetime.date.today(); md = d.day % 10 in (3, 8)   # 북평민속오일장 3·8일 장
pathlib.Path('/Users/hyewon/공모전/trip/docs/screenshots/case/meta.json').write_text(json.dumps({'date': d.isoformat(), 'market_day': md}, ensure_ascii=False))
print('meta', d, md)
PY
git status --short lib; echo "##### done $(date '+%T')"

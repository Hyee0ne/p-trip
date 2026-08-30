#!/usr/bin/env python3
"""심사 상태 확인. 읽기 전용.

    python3 tools/asc/review_status.py          # 지금 상태를 보여준다
    python3 tools/asc/review_status.py --quiet   # 지난번과 다를 때만 출력 (cron용)

`--quiet`는 마지막 상태를 .last_review_state 에 남긴다 (gitignore 대상).
"""
import os, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import ascapi as a

QUIET = "--quiet" in sys.argv
STATE_FILE = pathlib.Path(__file__).resolve().parent / ".last_review_state"

# 애플의 상태 코드는 영어다. 무슨 뜻인지 같이 적는다.
MEANING = {
    "PREPARE_FOR_SUBMISSION": "제출 전 (아직 심사에 안 들어감)",
    "WAITING_FOR_REVIEW": "심사 대기 중",
    "IN_REVIEW": "심사 중 — 사람이 보고 있다",
    "PENDING_DEVELOPER_RELEASE": "승인됨. 출시 버튼을 누르면 나간다",
    "PENDING_APPLE_RELEASE": "승인됨. 애플이 정한 날짜에 나간다",
    "PROCESSING_FOR_APP_STORE": "승인됨. 스토어에 올리는 중",
    "READY_FOR_SALE": "출시됐다",
    "REJECTED": "반려됨 — 심사 의견을 확인해야 한다",
    "METADATA_REJECTED": "메타데이터 반려 — 설명·스크린샷 등을 고쳐야 한다",
    "DEVELOPER_REJECTED": "우리가 내렸다",
    "INVALID_BINARY": "바이너리가 거부됐다",
}


def main():
    v = a.get(f"apps/{a.APP}/appStoreVersions?limit=1")
    if "_err" in v:
        if not QUIET:
            print(f"  조회 실패 [{v['_err']}] {str(v['_detail'])[:200]}")
        return 1
    if not v.get("data"):
        if not QUIET:
            print("  버전 레코드 없음")
        return 1

    va = v["data"][0]
    state = va["attributes"].get("appStoreState")
    ver = va["attributes"].get("versionString")
    b = a.get(f"appStoreVersions/{va['id']}/build").get("data")
    build = b["attributes"]["version"] if b else "없음"
    line = f"{ver} ({build}) — {state}: {MEANING.get(state, '?')}"

    if QUIET:
        prev = STATE_FILE.read_text().strip() if STATE_FILE.exists() else ""
        STATE_FILE.write_text(state)
        if prev == state:
            return 0          # 안 바뀌었으면 조용히 넘어간다
        print(f"  [상태 변경] {prev or '(처음)'} → {line}")
    else:
        print(f"  {line}")

    # 반려면 이유를 같이 보여준다 — 그게 다음에 할 일이다.
    if state in ("REJECTED", "METADATA_REJECTED"):
        r = a.get(f"apps/{a.APP}/appStoreVersions?limit=1&include=appStoreReviewDetail")
        print("  ⚠ App Store Connect → 해결 센터에서 심사 의견을 확인하세요.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

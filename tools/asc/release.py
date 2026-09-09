#!/usr/bin/env python3
"""새 버전 준비 · 빌드 연결 · 심사 제출. 문서가 단일 소스다 (등록정보 · 심사노트).

    python3 tools/asc/release.py version 1.0.2   # 버전 레코드 만들고 텍스트·심사노트·스크린샷 채운다 (되돌릴 수 있다)
    python3 tools/asc/release.py attach  1.0.2 7 # 빌드 7 이 처리되길 기다렸다가 버전에 붙인다
    python3 tools/asc/release.py submit  1.0.2   # ⚠ 심사 제출. 바깥으로 나가는 유일한 단계
    python3 tools/asc/release.py cancel          # 대기 중인 제출을 거둔다 (고치고 다시 submit)

`version`·`attach` 는 몇 번 다시 돌려도 같은 결과다. `submit` 만 한 번이다.
"""
import os, pathlib, re, subprocess, sys, time
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import ascapi as a

ROOT = pathlib.Path(__file__).resolve().parents[2]
DOC_STORE = ROOT / "docs" / "앱스토어_등록정보.md"
DOC_NOTES = ROOT / "docs" / "앱스토어_심사노트.md"
LOCALE = "ko"


def blocks(path):
    """헤딩별 첫 코드펜스. 헤딩 끝의 '(…)' 는 뗀다 — copydoc.py 와 같은 규칙."""
    out, cur = {}, None
    lines = path.read_text(encoding="utf-8").split("\n"); i = 0
    while i < len(lines):
        m = re.match(r"^##+ (.+)$", lines[i])
        if m:
            cur = re.sub(r"\s*\(.*?\)\s*$", "", m.group(1)).strip(); i += 1; continue
        if lines[i].startswith("```") and cur:
            i += 1; buf = []
            while i < len(lines) and not lines[i].startswith("```"):
                buf.append(lines[i]); i += 1
            out.setdefault(cur, "\n".join(buf).strip())
        i += 1
    return out


def need(b, k):
    if k not in b: raise SystemExit(f"문서에 '{k}' 블록이 없다. 있는 것: {list(b)}")
    return b[k]


def find_version(ver):
    v = a.get(f"apps/{a.APP}/appStoreVersions?filter[versionString]={ver}&filter[platform]=IOS")
    return v["data"][0] if v.get("data") else None


def prev_version(ver):
    v = a.get(f"apps/{a.APP}/appStoreVersions?filter[platform]=IOS&limit=10")
    others = [x for x in v.get("data", []) if x["attributes"]["versionString"] != ver]
    return others[0] if others else None


def cmd_version(ver):
    b = blocks(DOC_STORE); n = blocks(DOC_NOTES)
    desc = need(b, "설명"); kw = need(b, "키워드"); promo = need(b, "프로모션 텍스트"); news = need(b, "새로운 기능")
    urls = need(b, "지원 URL / 개인정보처리방침 URL")
    support = re.search(r"지원\s*:\s*(\S+)", urls).group(1)
    notes = need(n, "영문")
    for label, val, lim in [("설명", desc, 4000), ("키워드", kw, 100), ("프로모션", promo, 170), ("새로운 기능", news, 4000), ("심사노트", notes, 4000)]:
        if len(val) > lim: raise SystemExit(f"{label} 가 {lim}자를 넘는다: {len(val)}")

    prev = prev_version(ver)
    cur = find_version(ver)
    if cur is None:
        release_type = (prev or {}).get("attributes", {}).get("releaseType") or "AFTER_APPROVAL"
        r = a.post("appStoreVersions", {"data": {"type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": ver, "releaseType": release_type},
            "relationships": {"app": {"data": {"type": "apps", "id": a.APP}}}}})
        if not a.show(f"버전 {ver} 생성 ({release_type})", r): sys.exit(1)
        cur = r["data"]
    else:
        print(f"  = 버전 {ver} 있음: {cur['attributes']['appStoreState']}")
    vid = cur["id"]

    # 텍스트
    locs = a.get(f"appStoreVersions/{vid}/appStoreVersionLocalizations").get("data", [])
    loc = next((l for l in locs if l["attributes"]["locale"] == LOCALE), None)
    attrs = {"description": desc, "keywords": kw, "promotionalText": promo, "whatsNew": news, "supportUrl": support}
    if loc is None:
        r = a.post("appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations",
            "attributes": {"locale": LOCALE, **attrs},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
        if not a.show("ko 텍스트 생성", r): sys.exit(1)
        loc = r["data"]
    else:
        r = a.patch(f"appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": attrs}})
        if not a.show("ko 텍스트 갱신 (설명·키워드·프로모션·새로운 기능·지원 URL)", r): sys.exit(1)
    lid = loc["id"]

    # 스크린샷 — 새 버전에 안 넘어왔으면 docs/screenshots 를 올린다
    sets = a.get(f"appStoreVersionLocalizations/{lid}/appScreenshotSets").get("data", [])
    n_shots = sum(len(a.get(f"appScreenshotSets/{s['id']}/appScreenshots").get("data", [])) for s in sets)
    if n_shots == 0:
        print("  스크린샷 없음 → 업로드")
        subprocess.run([sys.executable, str(pathlib.Path(__file__).with_name("shots.py"))], env={**os.environ, "ASC_LID": lid}, check=False)
    else:
        print(f"  = 스크린샷 {n_shots}장 있음")

    # 심사 상세 — 연락처는 지난 버전에서 옮기고, 노트는 문서에서
    rd = a.get(f"appStoreVersions/{vid}/appStoreReviewDetail").get("data")
    if rd is None:
        contact = {}
        if prev:
            prd = a.get(f"appStoreVersions/{prev['id']}/appStoreReviewDetail").get("data")
            if prd:
                contact = {k: prd["attributes"].get(k) for k in ("contactFirstName", "contactLastName", "contactEmail", "contactPhone")}
        r = a.post("appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails",
            "attributes": {**contact, "demoAccountRequired": False, "notes": notes},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
        if not a.show("심사 상세 생성 (연락처 + 노트)", r): sys.exit(1)
    else:
        r = a.patch(f"appStoreReviewDetails/{rd['id']}", {"data": {"type": "appStoreReviewDetails", "id": rd["id"], "attributes": {"notes": notes, "demoAccountRequired": False}}})
        if not a.show("심사노트 갱신", r): sys.exit(1)
    print(f"  version id = {vid}")


def cmd_attach(ver, build_no, wait_min=25):
    cur = find_version(ver)
    if cur is None: raise SystemExit(f"버전 {ver} 없음 — 먼저 `version`")
    deadline = time.time() + wait_min * 60
    while True:
        bl = a.get(f"builds?filter[app]={a.APP}&filter[version]={build_no}&sort=-uploadedDate&limit=3").get("data", [])
        b = next((x for x in bl if x["attributes"].get("processingState") == "VALID"), None)
        if b: break
        states = [x["attributes"].get("processingState") for x in bl] or ["(아직 안 올라옴)"]
        if time.time() > deadline: raise SystemExit(f"빌드 {build_no} 처리 대기 초과: {states}")
        print(f"  빌드 {build_no} 처리 중… {states}"); time.sleep(60)
    r = a.patch(f"appStoreVersions/{cur['id']}/relationships/build", {"data": {"type": "builds", "id": b["id"]}})
    a.show(f"빌드 {build_no} 을 {ver} 에 연결", r)


def cmd_submit(ver):
    cur = find_version(ver)
    if cur is None: raise SystemExit(f"버전 {ver} 없음")
    if not a.get(f"appStoreVersions/{cur['id']}/build").get("data"): raise SystemExit("빌드가 안 붙어 있다 — 먼저 `attach`")
    r = a.post("reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": a.APP}}}}})
    if not a.show("제출 묶음 생성", r): sys.exit(1)
    rs = r["data"]["id"]
    r = a.post("reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
        "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": rs}},
                          "appStoreVersion": {"data": {"type": "appStoreVersions", "id": cur["id"]}}}}})
    if not a.show(f"묶음에 {ver} 추가", r): sys.exit(1)
    r = a.patch(f"reviewSubmissions/{rs}", {"data": {"type": "reviewSubmissions", "id": rs, "attributes": {"submitted": True}}})
    if not a.show("심사 제출", r): sys.exit(1)
    print("  state:", r["data"]["attributes"].get("state"))


def cmd_cancel():
    """심사 대기 중인 제출을 거둔다 — 스크린샷·텍스트를 고치려면 먼저 이걸 해야 한다.
    CANCELING → COMPLETE 로 바뀐 뒤에 다시 `submit` 한다."""
    rs = a.get(f"reviewSubmissions?filter[app]={a.APP}&filter[state]=WAITING_FOR_REVIEW,IN_REVIEW,READY_FOR_REVIEW,UNRESOLVED_ISSUES&limit=5").get("data", [])
    if not rs: print("  거둘 제출이 없다"); return
    for r in rs:
        rid = r["id"]
        a.show(f"제출 취소 {rid} ({r['attributes'].get('state')})",
               a.patch(f"reviewSubmissions/{rid}", {"data": {"type": "reviewSubmissions", "id": rid, "attributes": {"canceled": True}}}))
        for _ in range(30):
            st = a.get(f"reviewSubmissions/{rid}")["data"]["attributes"].get("state")
            if st == "COMPLETE": print("  → COMPLETE"); break
            print(f"  … {st}"); time.sleep(5)


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    {"version": lambda: cmd_version(args[0]),
     "attach": lambda: cmd_attach(args[0], args[1]),
     "submit": lambda: cmd_submit(args[0]),
     "cancel": cmd_cancel}[cmd]()

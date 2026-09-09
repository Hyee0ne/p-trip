#!/usr/bin/env python3
"""스크린샷 한 장을 갈아끼운다 — 같은 파일명은 지우고, 올리고, 파일명 순으로 다시 세운다.

    python3 tools/asc/shot_replace.py 1.0.2 docs/screenshots/1_home.png

shots.py 는 폴더를 통째로 올리는 도구라 한 장만 바꾸면 중복이 생긴다. 이건 한 장용이다.
"""
import hashlib, pathlib, sys, urllib.request, urllib.error
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import ascapi as a

DISPLAY = "APP_IPHONE_67"

def put_raw(op, chunk):
    h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
    req = urllib.request.Request(op["url"], data=chunk, headers=h, method=op["method"])
    try:
        urllib.request.urlopen(req, timeout=300); return None
    except urllib.error.HTTPError as e:
        return f"{e.code} {e.read().decode(errors='ignore')[:200]}"

def main(ver, path):
    f = pathlib.Path(path); data = f.read_bytes()
    v = a.get(f"apps/{a.APP}/appStoreVersions?filter[versionString]={ver}&filter[platform]=IOS")["data"][0]
    loc = next(l for l in a.get(f"appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"] if l["attributes"]["locale"] == "ko")
    sets = a.get(f"appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
    st = next(s for s in sets if s["attributes"]["screenshotDisplayType"] == DISPLAY)
    shots = a.get(f"appScreenshotSets/{st['id']}/appScreenshots")["data"]
    for s in shots:
        if s["attributes"].get("fileName") == f.name:
            a.show(f"지움 {f.name}", a.call("DELETE", f"appScreenshots/{s['id']}"))
    r = a.post("appScreenshots", {"data": {"type": "appScreenshots",
        "attributes": {"fileSize": len(data), "fileName": f.name},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": st["id"]}}}}})
    if not a.show(f"예약 {f.name}", r): sys.exit(1)
    shot = r["data"]
    for op in shot["attributes"]["uploadOperations"]:
        err = put_raw(op, data[op["offset"]:op["offset"] + op["length"]])
        if err: print("  ✗ 업로드", err); sys.exit(1)
    a.show(f"확정 {f.name}", a.patch(f"appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}))
    # 순서 — 파일명 순 (1_home, 2_depart, …)
    shots = a.get(f"appScreenshotSets/{st['id']}/appScreenshots")["data"]
    order = sorted(shots, key=lambda s: s["attributes"].get("fileName") or "")
    a.show("순서 정리 " + ", ".join(s["attributes"].get("fileName", "?") for s in order),
           a.patch(f"appScreenshotSets/{st['id']}/relationships/appScreenshots",
                   {"data": [{"type": "appScreenshots", "id": s["id"]} for s in order]}))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

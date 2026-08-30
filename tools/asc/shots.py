import hashlib, pathlib, sys, urllib.request, urllib.error, ascapi as a

LID="a2da5614-8dbd-4a67-ad7a-5e3ed05fe53b"
DIR=pathlib.Path(__file__).resolve().parents[2] / "docs" / "screenshots"
DISPLAY="APP_IPHONE_67"

def put_raw(op, chunk):
    """사전서명 URL에는 ASC 토큰을 절대 붙이지 않는다."""
    h={x["name"]:x["value"] for x in op.get("requestHeaders",[])}
    req=urllib.request.Request(op["url"], data=chunk, headers=h, method=op["method"])
    try:
        urllib.request.urlopen(req, timeout=300); return None
    except urllib.error.HTTPError as e:
        return f"{e.code} {e.read().decode(errors='ignore')[:200]}"

sets=a.get(f"appStoreVersionLocalizations/{LID}/appScreenshotSets").get("data",[])
sid=next((s["id"] for s in sets if s["attributes"]["screenshotDisplayType"]==DISPLAY), None)
if sid is None:
    r=a.post("appScreenshotSets", {"data":{"type":"appScreenshotSets",
        "attributes":{"screenshotDisplayType":DISPLAY},
        "relationships":{"appStoreVersionLocalization":{"data":{
            "type":"appStoreVersionLocalizations","id":LID}}}}})
    if not a.show("세트 생성", r): sys.exit(1)
    sid=r["data"]["id"]

# 지난 실패로 남은 미완성 예약을 지운다
for s in a.get(f"appScreenshotSets/{sid}/appScreenshots").get("data",[]):
    st=s["attributes"].get("assetDeliveryState",{}).get("state")
    if st!="COMPLETE":
        a.call("DELETE", f"appScreenshots/{s['id']}")
        print(f"  예약 정리: {s['attributes'].get('fileName')} ({st})")

for f in sorted(DIR.glob("*.png")):
    data=f.read_bytes()
    r=a.post("appScreenshots", {"data":{"type":"appScreenshots",
        "attributes":{"fileSize":len(data),"fileName":f.name},
        "relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":sid}}}}})
    if not a.show(f"예약 {f.name}", r): continue
    shot=r["data"]
    err=None
    for op in shot["attributes"]["uploadOperations"]:
        err=put_raw(op, data[op["offset"]:op["offset"]+op["length"]])
        if err: break
    if err:
        print(f"  ✗ 업로드 {f.name}: {err}"); continue
    a.show(f"확정 {f.name}", a.patch(f"appScreenshots/{shot['id']}",
        {"data":{"type":"appScreenshots","id":shot["id"],
                 "attributes":{"uploaded":True,
                               "sourceFileChecksum":hashlib.md5(data).hexdigest()}}}))

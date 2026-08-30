#!/usr/bin/env python3
"""제출 전 무엇이 비어 있는지 조회. 읽기 전용."""
import json, os, time, urllib.request, urllib.error, jwt

KEY_ID="7U29A76MBG"; ISSUER="ea714c32-bf27-4e6f-b4cd-cadb3b7a3908"
P8=os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_7U29A76MBG.p8")
APP="6806749553"

def get(path):
    now=int(time.time())
    t=jwt.encode({"iss":ISSUER,"iat":now,"exp":now+600,"aud":"appstoreconnect-v1"},
                 open(P8).read(),algorithm="ES256",headers={"kid":KEY_ID,"typ":"JWT"})
    u="https://api.appstoreconnect.apple.com/v1/"+path
    try: return json.load(urllib.request.urlopen(
        urllib.request.Request(u,headers={"Authorization":"Bearer "+t}),timeout=30))
    except urllib.error.HTTPError as e: return {"_err":e.code,"_b":e.read().decode()[:300]}

def mark(ok): return "OK  " if ok else "비어있음"

v=get(f"apps/{APP}/appStoreVersions?limit=1")
if "_err" in v: print("  HTTP",v["_err"],v["_b"]); raise SystemExit
vd=v.get("data",[])
if not vd: print("  버전 레코드 없음"); raise SystemExit
va=vd[0]; vid=va["id"]; at=va["attributes"]
print(f"\n[버전] {at.get('versionString')}  상태: {at.get('appStoreState')}  "
      f"공개방식: {at.get('releaseType')}")

loc=get(f"appStoreVersions/{vid}/appStoreVersionLocalizations")
print("\n[스토어 텍스트]")
for l in loc.get("data",[]):
    a=l["attributes"]
    print(f"  언어 {a.get('locale')}")
    for k,label in [("description","설명"),("keywords","키워드"),
                    ("promotionalText","프로모션"),("whatsNew","새로운 기능"),
                    ("supportUrl","지원 URL"),("marketingUrl","마케팅 URL")]:
        val=a.get(k)
        print(f"    {label:12} {mark(bool(val))}" + (f"  ({str(val)[:60]})" if val else ""))
    # 스크린샷
    s=get(f"appStoreVersionLocalizations/{l['id']}/appScreenshotSets")
    sets=s.get("data",[])
    if not sets: print(f"    {'스크린샷':12} 비어있음")
    for st in sets:
        shots=get(f"appScreenshotSets/{st['id']}/appScreenshots")
        print(f"    {'스크린샷':12} {st['attributes'].get('screenshotDisplayType')}: "
              f"{len(shots.get('data',[]))}장")

print("\n[앱 정보]")
info=get(f"apps/{APP}/appInfos?limit=1")
if info.get("data"):
    iid=info["data"][0]["id"]
    ia=info["data"][0]["attributes"]
    print(f"  연령등급 {mark(bool(ia.get('appStoreAgeRating')))}  {ia.get('appStoreAgeRating') or ''}")
    il=get(f"appInfos/{iid}/appInfoLocalizations")
    for l in il.get("data",[]):
        a=l["attributes"]
        print(f"  언어 {a.get('locale')}: 이름 {mark(bool(a.get('name')))} "
              f"부제 {mark(bool(a.get('subtitle')))} "
              f"개인정보URL {mark(bool(a.get('privacyPolicyUrl')))}"
              + (f"  ({a.get('privacyPolicyUrl')})" if a.get('privacyPolicyUrl') else ""))

print("\n[심사 상세]")
d=get(f"appStoreVersions/{vid}/appStoreReviewDetail")
if d.get("data"):
    a=d["data"]["attributes"]
    print(f"  연락처 {mark(bool(a.get('contactEmail')))}  "
          f"심사노트 {mark(bool(a.get('notes')))}")
else:
    print("  심사 상세 없음 — 연락처·심사노트 비어있음")

print("\n[빌드 연결]")
b=get(f"appStoreVersions/{vid}/build")
print("  " + ("연결됨" if b.get("data") else "이 버전에 빌드가 아직 연결 안 됨"))

print("\n[빌드의 실제 버전 문자열]")
bs=get(f"builds?filter[app]={APP}&limit=3&include=preReleaseVersion")
for inc in bs.get("included",[]):
    if inc["type"]=="preReleaseVersions":
        print("  preReleaseVersion:", inc["attributes"].get("version"))
for b in bs.get("data",[]):
    print("  build CFBundleVersion:", b["attributes"].get("version"),
          " 처리상태:", b["attributes"].get("processingState"))
print("\n  → 버전 레코드가 '1.0', 빌드가 '1.0.0'이면 서로 붙지 않습니다.")

"""App Store Connect API 공용 모듈."""
import json, os, time, urllib.request, urllib.error, jwt

KEY_ID="7U29A76MBG"; ISSUER="ea714c32-bf27-4e6f-b4cd-cadb3b7a3908"
P8=os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_7U29A76MBG.p8")
APP="6806749553"
BASE="https://api.appstoreconnect.apple.com/v1/"

def _tok():
    now=int(time.time())
    return jwt.encode({"iss":ISSUER,"iat":now,"exp":now+900,"aud":"appstoreconnect-v1"},
                      open(P8).read(),algorithm="ES256",headers={"kid":KEY_ID,"typ":"JWT"})

def call(method, path, body=None, raw=None, headers=None, base=True):
    url = (BASE+path) if base else path
    h={"Authorization":"Bearer "+_tok()}
    data=None
    if body is not None:
        data=json.dumps(body).encode(); h["Content-Type"]="application/json"
    elif raw is not None:
        data=raw
    if headers: h.update(headers)
    req=urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        r=urllib.request.urlopen(req, timeout=120)
        b=r.read()
        return json.loads(b) if b and b[:1] in (b"{",b"[") else {"_status":r.status}
    except urllib.error.HTTPError as e:
        body=e.read().decode(errors="ignore")
        try: err=json.loads(body)
        except Exception: err={"raw":body[:400]}
        return {"_err":e.code,"_detail":err}

def get(p): return call("GET",p)
def patch(p,b): return call("PATCH",p,b)
def post(p,b): return call("POST",p,b)

def show(label, res):
    if "_err" in res:
        d=res["_detail"]
        msgs=[f"{e.get('title')}: {e.get('detail')}" for e in d.get("errors",[])] or [str(d)[:300]]
        print(f"  ✗ {label}  [{res['_err']}]")
        for m in msgs: print(f"      {m}")
        return False
    print(f"  ✓ {label}")
    return True

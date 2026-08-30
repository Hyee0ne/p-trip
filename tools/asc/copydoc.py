"""docs/앱스토어_등록정보.md 의 코드펜스를 헤딩별로 뽑는다. 손으로 옮겨 적지 않는다."""
import re, pathlib
DOC = pathlib.Path(__file__).resolve().parents[2] / "docs" / "앱스토어_등록정보.md"

def blocks():
    txt = DOC.read_text(encoding="utf-8")
    out, cur = {}, None
    lines = txt.split("\n"); i = 0
    while i < len(lines):
        m = re.match(r"^##+ (.+)$", lines[i])
        if m:
            cur = re.sub(r"\s*\(.*?\)\s*$", "", m.group(1)).strip()
            i += 1; continue
        if lines[i].startswith("```") and cur:
            i += 1; buf = []
            while i < len(lines) and not lines[i].startswith("```"):
                buf.append(lines[i]); i += 1
            out.setdefault(cur, "\n".join(buf).strip())
        i += 1
    return out

B = blocks()
def get(name): 
    v = B.get(name)
    if v is None: raise SystemExit(f"문서에서 '{name}' 블록을 못 찾음. 있는 것: {list(B)}")
    return v

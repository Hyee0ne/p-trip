#!/usr/bin/env python3
"""키노트가 뽑은 PDF 는 그림을 PNG 원본으로 품어 20MB 를 넘는다. 그림만 JPEG(긴 변 1600px, 품질 85)로 바꿔 줄인다.
글자는 벡터 그대로라 검색·복사가 된다. 실행: python3 tools/docs/shrink_pdf.py <in.pdf> [out.pdf]  (out 생략 시 제자리)"""
import io, os, sys, fitz
from PIL import Image
src = sys.argv[1]; dst = sys.argv[2] if len(sys.argv) > 2 else src
doc = fitz.open(src); done = set()
for page in doc:
    for img in page.get_images(full=True):
        xref = img[0]
        if xref in done: continue
        done.add(xref)
        raw = doc.extract_image(xref)['image']
        im = Image.open(io.BytesIO(raw)).convert('RGB'); w, h = im.size
        scale = min(1.0, 1600 / max(w, h))
        if scale < 1: im = im.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
        b = io.BytesIO(); im.save(b, 'JPEG', quality=85, optimize=True)
        if len(b.getvalue()) < len(raw): page.replace_image(xref, stream=b.getvalue())
tmp = dst + '.tmp.pdf'
doc.save(tmp, garbage=4, deflate=True, clean=True); doc.close(); os.replace(tmp, dst)
print(f'{dst}: {os.path.getsize(dst) / 1048576:.1f} MB')

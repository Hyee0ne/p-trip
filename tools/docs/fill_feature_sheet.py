#!/usr/bin/env python3
"""공모전 「기능설명서」 양식(pptx)을 P의 여행 내용으로 채운다.

입력: docs/2026 … 기능설명서 양식(작성용).pptx (원본은 손대지 않는다)
출력: docs/기능설명서_P의여행.pptx
이미지: docs/screenshots/*.png + IMG_DIR(시뮬레이터 추가 캡처). 없는 파일은 건너뛰고 알린다.

실행: python3 tools/docs/fill_feature_sheet.py [IMG_DIR]
"""
import copy, pathlib, sys
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor

# ⚠ 표의 첫 행은 템플릿 표 스타일(firstRow)이 흰 글자다 — 색을 안 주면 흰 칸에 흰 글자로 사라진다.
#   (원본 가이드 문구는 빨간색을 명시해서 보였다.) 내용 글자는 전부 잉크색을 명시한다.
INK = RGBColor(0x1F, 0x23, 0x26)

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'docs' / '2026 관광데이터 활용 공모전 웹앱 개발 부문 기능설명서 양식(작성용).pptx'
OUT = ROOT / 'docs' / '기능설명서_P의여행.pptx'
SHOTS = ROOT / 'docs' / 'screenshots'
IMG_DIR = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else None
ICON = ROOT / 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png'
SHARE = ROOT / 'app/test/goldens/share_card_8stops.png'

missing = []

def img(name):
    """스크린샷 이름 → 경로. 스토어 스크린샷 → 추가 캡처 → 골든 순."""
    for base in (SHOTS, IMG_DIR, ROOT / 'app/test/goldens'):
        if base is None: continue
        p = base / name
        if p.exists(): return p
    missing.append(name); return None

def set_cell(cell, lines, size=13, bold_first=False, align=PP_ALIGN.LEFT, color=INK):
    """셀 글을 통째로 바꾼다. lines: str 또는 [str]. 빈 줄은 '' 로."""
    if isinstance(lines, str): lines = [lines]
    tf = cell.text_frame
    tf.word_wrap = True
    # 첫 문단은 남기고 비운다 (문단 속성 유지), 나머지는 지운다
    for p in list(tf.paragraphs)[1:]:
        p._p.getparent().remove(p._p)
    first = tf.paragraphs[0]
    for r in list(first.runs): r._r.getparent().remove(r._r)
    for i, line in enumerate(lines):
        p = first if i == 0 else tf.add_paragraph()
        p.alignment = align
        run = p.add_run(); run.text = line
        run.font.size = Pt(size)
        if bold_first and i == 0: run.font.bold = True
        if color is not None: run.font.color.rgb = color

def find_table(slide, name=None):
    for sh in slide.shapes:
        if sh.has_table and (name is None or sh.name == name): return sh
    raise KeyError(name)

def remove_shape(slide, shape_id):
    for sh in slide.shapes:
        if sh.shape_id == shape_id:
            sh._element.getparent().remove(sh._element); return True
    return False

def delete_slide(prs, index):
    sldIdLst = prs.slides._sldIdLst
    sldId = list(sldIdLst)[index]
    prs.part.drop_rel(sldId.rId)
    sldIdLst.remove(sldId)

def duplicate_slide(prs, index):
    """그림 없는 슬라이드(표·도형만)를 복제해 맨 뒤에 붙인다. 위치는 호출부가 옮긴다."""
    src = prs.slides[index]
    dst = prs.slides.add_slide(src.slide_layout)
    for sh in list(dst.shapes):  # 레이아웃이 만든 자리표시자 제거
        sh._element.getparent().remove(sh._element)
    for sh in src.shapes:
        dst.shapes._spTree.append(copy.deepcopy(sh._element))
    return dst

def move_slide(prs, old_index, new_index):
    sldIdLst = prs.slides._sldIdLst
    ids = list(sldIdLst)
    el = ids[old_index]
    sldIdLst.remove(el)
    sldIdLst.insert(new_index, el)

def add_shot(slide, path, left, top, box_w, box_h, pad=0.06):
    """상자(인치) 안에 비율 유지로 가운데 놓는다."""
    from PIL import Image
    with Image.open(path) as im: w, h = im.size
    bw, bh = box_w - pad * 2, box_h - pad * 2
    scale = min(bw / w, bh / h)
    pw, ph = w * scale, h * scale
    slide.shapes.add_picture(str(path), Inches(left + pad + (bw - pw) / 2), Inches(top + pad + (bh - ph) / 2), Inches(pw), Inches(ph))

# ──────────────────────────────── 내용 ────────────────────────────────
TEAM = '라이스쿠키'
NAME = 'P의여행:국도편'  # App Store 이름이 메인
APP_STORE_URL = 'https://apps.apple.com/kr/app/id6806749553'
VIDEO_URL = 'https://youtu.be/q4jvO63vvQA'  # 데모 영상. 비어 있으면 줄을 넣지 않는다.

INTRO = {
    'name': 'P의여행:국도편  (P의 여행 — 국도 위의 발견 레이더)',
    'type': '앱 서비스 (iOS) · App Store 출시',
    'summary': [
        '목적지 없이 국도를 달려도 휴일을 버리지 않게 — 관광데이터로 검증된 발견을 지나치기 전에 알려주는 즉흥 여행 앱.',
        '국도와 방향만 고르면, 앞쪽에 있는 오늘 서는 장·일몰·확인된 맛집을 카드 한 장으로 건넵니다.',
    ],
    'why': [
        '• 요즘 「풍향중」처럼 목적지 없이 떠나는 여행이 유행입니다. 정해진 관광지보다 국도를 달리다 우연히 만나는 것에서 새로움을 찾는 니즈가 커졌습니다.',
        '• 그런데 정말 지도책 한 권만 들고 나서면 일반인에게는 리스크가 큽니다. 문 닫은 식당, 장이 안 서는 날, 지나치고 나서야 알게 되는 명소 — 소중한 휴일 하루를 통째로 버릴 수 있습니다.',
        '• 한국관광공사 관광정보에는 그 리스크를 줄일 재료가 이미 있습니다. 영업시간·휴무일·장날·사진·연관 관광지. 이를 국도 선형과 현재 위치·진행 방향에 겹치면 "지금 이 길 앞에 무엇이 있는가"가 됩니다.',
        '• 그래서 목적지는 묻지 않되, 우연을 데이터로 받쳐 주는 앱을 만들었습니다. 국도를 달리며 만난 우연이 하루의 추억(여행기)으로 남고, 발길이 대도시 밖 소도시·시장·자연으로 흩어지는 일과도 맞닿습니다.',
    ],
}

FEATURES_LIST = [
    '1. 지도에서 길 고르고, 방향만 정하고 출발 — Apple 지도 위에 국도 51선 전부. 내 주변에서 탈 수 있는 길과 노선별 큐레이션 한 줄(「오늘 이 길에 장이 3곳 서요」). 목적지·도착 시각은 묻지 않는다 — 북/남(동/서)만 고르면 티맵·애플 지도로 길안내를 넘긴다 (앱은 내비게이션이 아니다)',
    '2. 발견 레이더 — 현재 위치 + 진행 방향 반경 5km에서 영업정보·사진이 확인된 스팟만 전면 카드 한 장으로. 별점·후기는 쓰지 않는다 — 신뢰는 데이터 완성도로. 장날·일몰·마감 임박을 우선. 넘기기 / 들르기 / 찜',
    '3. 소리와 알림 — 내비를 켜둔 채여도 음성으로 먼저(내비 음성을 끊지 않고 잠깐 낮춘다). 놓치면 알림에 남고, 누르면 그 발견의 상세로',
    '4. 들른 뒤 이어가기 — 차가 2분 서 있으면 「여기서 앞쪽으로」 앞쪽 10km 후보 3곳. 여행 중 다른 국도로 갈아타도 여행과 기록은 이어진다',
    '5. 여행기 — 하루가 「N번 국도에서 생긴 일」 한 편으로. 지나온 길 포스터·들른 곳 타임라인·공유 카드(시작·끝 300m 자동 삭제)·국도 51선 수집 진행률',
]

# 핵심 기능별 흐름도 (최대 5장). 캡처 4장 + 단계 설명 4칸.
FLOWS = [
    {
        'title': '길 고르기 · 방향만 정하고 출발',
        'desc': '목적지가 아니라 길을 고른다. 홈 지도에 국도 51선이 다 그려져 있고, 방향만 정하면 출발이다. 길안내는 티맵·애플 지도로 넘긴다.',
        'shots': ['1_home.png', 'home_expanded.png', '2_depart.png', 'handoff-t16.png'],
        'steps': [
            '① 홈 = 지도. 국도 51선 파란 선, 「여기서 탈 수 있는 길」과 노선별 큐레이션 한 줄',
            '② 시트를 올리면 「국도 51선」 전체. 남북(홀수)·동서(짝수) 필터',
            '③ 노선을 고르면 「여기서 어느 쪽으로 갈까요?」 — 북쪽/남쪽만 정한다. 목적지는 묻지 않는다',
            '④ 티맵 / 애플 지도로 핸드오프. 앱은 턴바이턴·ETA를 만들지 않는다',
        ],
    },
    {
        'title': '발견 레이더 · 전면 카드',
        'desc': '현재 위치와 진행 방향 반경 5km에서 영업정보·사진이 확인된 스팟만 골라 카드 한 장으로 알린다. 장날·일몰·마감 임박이 우선이다.',
        'shots': ['4_radar.png', '3_card.png', '5_spot.png', 'radar-t26.png'],
        'steps': [
            '① 레이더: 내 위치 기준 앞쪽 스팟(유형색 점). 경로를 따라가지 않아 길을 바꿔도 그대로 작동',
            '② 발견 카드: 「오늘이 마침 북평민속오일장이에요 · 여기서 약 1.2km」 + 넘기기 / 들르기 / 찜',
            '③ 상세: 관광공사 사진·개요·영업정보. 별점 없이 「네이버 후기 보기」 링크만',
            '④ 「들르기」를 누르면 티맵으로 목적지가 바뀌고, 레이더 아래 「오늘 들른 곳」 자취에 사진으로 남는다',
        ],
    },
    {
        'title': '들른 뒤 이어가기 · 길 바꾸기',
        'desc': '밥을 먹고 나서 다음 행선지를 고르는 순간을 받친다. 정차 2분이면 앞쪽 10km 후보를 펼치고, 다른 국도로 갈아타도 하루의 기록은 이어진다.',
        'shots': ['next2-t17.png', 'next2-t22.png', 'switch-t16.png', 'radar-t14.png'],
        'steps': [
            '① 들른 뒤 차가 2분 서 있으면 「여기서 앞쪽으로」가 저절로 열린다',
            '② 앞쪽 10km 안 후보 3곳 + 「그냥 7번 국도로 돌아가기」',
            '③ 상단 뱃지를 누르면 「길을 바꿀까요?」 — 여기서 탈 수 있는 다른 국도로 갈아탄다',
            '④ 여행은 하루 하나, 국도는 구간으로 이어진다 (43 → 6번 국도). 거리·들른 곳이 그대로',
        ],
    },
    {
        'title': '여행기 · 공유 포스터 · 국도 51선 수집',
        'desc': '「오늘 여행 마치기」를 누르면 지나온 길과 들른 곳이 한 편의 여행기가 된다. 포스터 한 장으로 공유하고, 지나온 국도가 51선 중 몇 선째인지 쌓인다.',
        'shots': ['trip-t16.png', 'share_card_8stops.png', 'my-t8.png', 'radar-t14.png'],
        'steps': [
            '① 「EP.6 — 43번 국도에서 생긴 일」: 실제 GPS 선 포스터 + 들른 곳 타임라인',
            '② 공유 카드: 지도·들른 곳 번호 목록·「들른 발견 N」. 시작·끝 300m는 자동으로 잘린다',
            '③ 마이: 여행기 목록·찜·국도 51선 수집 진행률·설정',
            '④ 레이더 「오늘 여행 마치기」 한 번으로 하루가 닫힌다',
        ],
    },
    {
        'title': '소리 · 알림 · 설정',
        'desc': '운전 중엔 화면을 볼 수 없다. 카드는 소리로 먼저 나가고, 놓치면 알림에 남는다. 위치는 출발할 때, 알림은 처음 달린 뒤에 묻는다.',
        'shots': ['onboard3-t6.png', '3_card.png', 'myset2-t8.png', '5_spot.png'],
        'steps': [
            '① 온보딩 마지막 장: 「앞쪽에 뭐가 있는지, 카드 한 장으로」 — 「내비를 켜둔 채여도 소리로 먼저」 「놓쳐도 알림에 남아요」',
            '② 카드 문장을 그대로 읽어준다. 내비 음성을 끊지 않고 잠깐 낮췄다 되돌린다',
            '③ 설정: 「앱을 꺼둬도 알림」(백그라운드 위치는 옵트인) · 「발견 간격」 자주·보통·가끔 · 데이터 출처. 낭독은 레이더의 스피커 버튼',
            '④ 알림을 누르면 그 발견의 상세로 바로 열린다',
        ],
    },
]

TOUR_APIS = [
    ('한국관광공사 국문 관광정보 서비스(KorService2) — 지역기반 관광정보 조회 areaBasedList2',
     '전국 관광지·음식점·문화시설·쇼핑(5일장·상설시장) 목록을 시군구 단위로 수집해 국도 51선 선형 반경 회랑 안의 스팟만 적재 (19,957건). 레이더·발견 카드의 후보가 된다'),
    ('국문 관광정보 — 공통정보 조회 detailCommon2 · 소개정보 조회 detailIntro2',
     '개요·영업시간·휴무일·장날(5일장)·전화를 받아 신뢰도 게이트(영업정보·사진 확인) 근거와 카드 본문(「3·8일에만 서는 장이라, 다음 장은 5일 뒤예요」)을 만든다'),
    ('국문 관광정보 — 이미지정보 조회 detailImage2',
     '관광공사 사진을 전면 카드·스팟 상세·「오늘 들른 곳」 자취에 원본 그대로(워터마크 포함) 쓴다. 사진이 없는 곳은 카드로 띄우지 않는다'),
    ('국문 관광정보 — 법정동코드 조회 ldongCode2 · 위치기반 관광정보 조회 locationBasedList2',
     '시군구 코드 순회 수집과 연관 관광지 이름 매칭의 지역 키. 위치기반 조회는 회랑 보강·검증에 쓴다'),
    ('관광지별 연관 관광지 정보 서비스(TarRlteTarService1) — areaBasedList1 (baseYm 지정)',
     '기준연월 두 시점(예: 202603·202606)을 각각 받아 비교해 "요즘 더 가는 곳"의 변화율을 산출 → 노선 큐레이션 한 줄(「요즘 이 길에 발길이 늘었어요」)과 「들른 차들은 다음에 ○○로 갔어요」의 근거. 두 시점이 없는 노선만 그 달의 연관 순위로 보조하되 문구를 달리 쓴다(「이 길로 다녀간 사람이 많아요」). 별점·후기는 쓰지 않는다'),
]

OTHER_DATA = [
    ('한국천문연구원 출몰시각 정보 OpenAPI (RiseSetInfoService)',
     '전망 스팟이 있는 0.1° 격자 × 앞날 30일의 일몰 시각을 미리 캐시. 일몰 40분 전 뷰포인트 카드·알림(「곧 추암 촛대바위에 해가 져요」)의 기준'),
    ('소상공인시장진흥공단 전국전통시장표준데이터 (파일, CSV)',
     '장날(3·8일 등)을 관광공사의 시장 스팟에 결합. 「오늘이 마침 장날」 카드와 다음 장 안내. 시장을 새 스팟으로 만들지 않고 사진·개요가 있는 관광공사 스팟에만 붙인다'),
    ('국토교통부 일반국도 도로중심선 (파일, SHP)',
     '국도 51선 선형. 홈 지도 폴리라인, 회랑 판정(스팟 적재 기준), 진출점 계산, 여행기의 국도 51선 수집(지나온 점 맵매칭)에 쓴다'),
]

DIFF = [
    '• 목적지가 아니라 길을 고른다 — 내비의 문법을 뒤집은 진입 흐름. 출발 전 검색·계획을 요구하지 않고 정보는 달리면서 나온다',
    '• 경로가 아니라 현재 위치 기준 — 길을 바꿔도 목적지가 바뀌어도 그대로 작동. 내비와 경쟁하지 않고 티맵 위에서 함께 돈다(핸드오프)',
    '• 시간에 걸린 발견 — 장날·일몰·마감 임박을 관광정보에 겹쳐 "지금 아니면 없는 것"을 우선한다 (관광공사 + 천문연 + 전통시장 데이터 결합)',
    '• 신뢰는 데이터 완성도로 — 별점·후기 없이 영업정보·사진이 확인된 곳만. 큐레이션은 연관 관광지 두 시점의 변화율(이동 흔적)이 우선, 변화를 못 재는 곳만 순위로 보조',
    '• 운전 중 안전 — 전면 카드 한 장·원형 버튼 3개·음성 우선·재촉 없음(카운트다운·"빨리 결정" 없음)',
    '• 계정·광고·추적 없음. 정확한 GPS 좌표는 기기를 떠나지 않는다(서버엔 0.01° 격자만) · 실제 출시(App Store), 전국 스팟 19,957건, 국도 51선',
]
PLAN = [
    '• 코스 자동 생성 — 노선을 구간으로 잘라 코스를 만든다 (지금은 7번 국도 등 손 큐레이션)',
    '• 연관 관광지 두 시점 축적 → 변화율 큐레이션(「요즘 이 길에 발길이 늘었어요」)이 전국 노선으로 수렴',
    '• 기간 한정 발견 확대 — 축제·행사(관광공사 행사정보)·계절(단풍·벚꽃)·야간 개장',
    '• 여행기 백업(계정 없이 iCloud) · 공유 포스터 고도화 · 지역별 국도 수집 뱃지',
    '• 지자체·관광공사와 국도 단위 큐레이션 협업, 전통시장·장날 정보 갱신 자동화',
    '• Android 포팅 (코드 분기 유지 중) · 웹 미리보기(길 고르기까지)',
]

# ──────────────────────────────── 채우기 ────────────────────────────────
prs = Presentation(str(SRC))
S = prs.slides

# 1 표지
t = find_table(S[0]).table
set_cell(t.cell(0, 1), TEAM, size=20, align=PP_ALIGN.CENTER)
set_cell(t.cell(1, 1), NAME, size=20, align=PP_ALIGN.CENTER)

# 2 서비스 소개
t = find_table(S[1]).table
set_cell(t.cell(0, 1), INTRO['name'], size=16)
set_cell(t.cell(1, 1), INTRO['type'], size=15)
# 링크 줄 — 하이퍼링크 런으로 (클릭되게)
tf = t.cell(1, 1).text_frame
p = tf.add_paragraph(); r = p.add_run(); r.text = 'App Store  '; r.font.size = Pt(12); r.font.color.rgb = INK
r = p.add_run(); r.text = APP_STORE_URL; r.font.size = Pt(12); r.hyperlink.address = APP_STORE_URL
if VIDEO_URL:
    p = tf.add_paragraph(); r = p.add_run(); r.text = '데모 영상  '; r.font.size = Pt(12); r.font.color.rgb = INK
    r = p.add_run(); r.text = VIDEO_URL; r.font.size = Pt(12); r.hyperlink.address = VIDEO_URL
set_cell(t.cell(2, 1), INTRO['summary'], size=14, bold_first=True)
set_cell(t.cell(3, 1), INTRO['why'], size=12)

# 3 핵심기능 목록
t = find_table(S[2]).table
set_cell(t.cell(0, 1), FEATURES_LIST, size=14)

# 4 이미지
t_sh = find_table(S[3]); t = t_sh.table
set_cell(t.cell(0, 1), '', size=12); set_cell(t.cell(1, 1), '', size=12)
left0 = Emu(t_sh.left).inches + Emu(t.columns[0].width).inches
top0 = Emu(t_sh.top).inches
r0, r1 = Emu(t.rows[0].height).inches, Emu(t.rows[1].height).inches
cw = Emu(t.columns[1].width).inches
if ICON.exists():
    # 양식은 '로고 또는 대표 이미지 1개' — 아이콘 하나만. 링크·문구는 2번 슬라이드에 있다.
    add_shot(S[3], ICON, left0, top0, cw, r0, pad=0.12)
else:
    missing.append(str(ICON))
detail = ['1_home.png', '2_depart.png', '3_card.png', '4_radar.png', '5_spot.png']
n = len(detail); gap = 0.18; ph = r1 - 0.2; pw = ph * 1320 / 2868
total = n * pw + (n - 1) * gap
x = left0 + (cw - total) / 2
for name in detail:
    p = img(name)
    if p: S[3].shapes.add_picture(str(p), Inches(x), Inches(top0 + r0 + 0.1), Inches(pw), Inches(ph))
    x += pw + gap

# 6 흐름도 — 원본(인덱스 5)을 채우고, 나머지는 복제해서 채운다
def fill_flow(slide, no, flow):
    remove_shape(slide, 19)  # 회색 안내 박스
    head = find_table(slide, '표 14').table
    set_cell(head.cell(0, 0), f'핵심 기능{no}', size=14, bold_first=True, align=PP_ALIGN.CENTER)
    set_cell(head.cell(0, 1), flow['title'], size=14, bold_first=True)
    set_cell(head.cell(1, 1), flow['desc'], size=11.5)
    body_sh = find_table(slide, '표 7'); body = body_sh.table
    left = Emu(body_sh.left).inches; top = Emu(body_sh.top).inches
    colw = [Emu(c.width).inches for c in body.columns]
    rowh = [Emu(r.height).inches for r in body.rows]
    y_img = top + rowh[0]
    x = left
    for i in range(4):
        set_cell(body.cell(1, i), '', size=10)
        set_cell(body.cell(2, i), flow['steps'][i], size=10.5)
        p = img(flow['shots'][i])
        if p: add_shot(slide, p, x, y_img, colw[i], rowh[1], pad=0.08)
        x += colw[i]

fill_flow(S[5], 1, FLOWS[0])
extra = []
for i, flow in enumerate(FLOWS[1:], start=2):
    dst = duplicate_slide(prs, 5)
    fill_flow(dst, i, flow)
    extra.append(dst)

# 7 OpenAPI
t = find_table(S[6]).table
for i, (api, desc) in enumerate(TOUR_APIS):
    set_cell(t.cell(i * 2, 2), api, size=11, bold_first=True)
    set_cell(t.cell(i * 2 + 1, 2), desc, size=10)

# 8 기타 데이터
remove_shape(S[7], 6)
t = find_table(S[7]).table
for i, (nm, desc) in enumerate(OTHER_DATA):
    set_cell(t.cell(i * 2, 2), nm, size=11, bold_first=True)
    set_cell(t.cell(i * 2 + 1, 2), desc, size=10)

# 9 차별성·발전계획
t = find_table(S[8]).table
set_cell(t.cell(0, 1), DIFF, size=11.5)
set_cell(t.cell(1, 1), PLAN, size=11.5)

# 순서: 복제한 흐름도를 6번 슬라이드 뒤로. 5번(지역 특화)은 지운다 — 전국 서비스라 해당 없음.
count = len(prs.slides._sldIdLst)
for k, _ in enumerate(extra):
    move_slide(prs, count - len(extra) + k, 6 + k)   # 원본 흐름도(인덱스 5) 바로 뒤에 차례로
delete_slide(prs, 4)

OUT.parent.mkdir(exist_ok=True)
prs.save(str(OUT))
print('saved', OUT.relative_to(ROOT), '| slides:', len(prs.slides))
if missing: print('MISSING images:', missing)

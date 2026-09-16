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
ICON = ROOT / 'docs/썸네일/썸네일_밝음.png'  # 대표 이미지(썸네일). 아이콘 대신 로고+이름 이미지 (2026-09-16)
SHARE = ROOT / 'app/test/goldens/share_card_8stops.png'

missing = []

def img(name):
    """스크린샷 이름 → 경로. 스토어 스크린샷 → 추가 캡처 → 골든 순."""
    for base in (SHOTS, IMG_DIR, ROOT / 'app/test/goldens'):
        if base is None: continue
        p = base / name
        if p.exists(): return p
    missing.append(name); return None

def set_cell(cell, lines, size=13, bold_first=False, align=PP_ALIGN.LEFT, color=INK, gap=5):
    """셀 글을 통째로 바꾼다. lines: str 또는 [str]. 빈 줄은 '' 로.
    줄바꿈 규칙 (2026-09-16, 가독성): '• 제목' / '1. 제목' 줄은 **굵게** 하고 앞에 간격을 둔다.
    '- 세부' 줄은 들여쓰기(≒0.22in)하고 '‒ ' 로 시작한다. 한 줄에 한 생각."""
    from pptx.oxml.ns import qn
    import re as _re
    if isinstance(lines, str): lines = [lines]
    tf = cell.text_frame
    tf.word_wrap = True
    for p in list(tf.paragraphs)[1:]:
        p._p.getparent().remove(p._p)
    first = tf.paragraphs[0]
    for r in list(first.runs): r._r.getparent().remove(r._r)
    for i, line in enumerate(lines):
        p = first if i == 0 else tf.add_paragraph()
        p.alignment = align
        head = bool(_re.match(r'^(• |\d+\. |[①②③④⑤])', line))
        sub = line.startswith('- ')
        text = ('‒ ' + line[2:]) if sub else line
        if sub:
            pPr = p._p.get_or_add_pPr()
            pPr.set('marL', str(int(Inches(0.22)))); pPr.set('indent', str(-int(Inches(0.14))))
        if head and i > 0: p.space_before = Pt(gap)
        run = p.add_run(); run.text = text
        run.font.size = Pt(size if not sub else size - 0.5)
        if (bold_first and i == 0) or head: run.font.bold = True
        if color is not None: run.font.color.rgb = color
        if sub: run.font.color.rgb = RGBColor(0x3E, 0x43, 0x47)

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
    'name': 'P의여행:국도편  (국도 위의 발견 레이더)',
    'type': '앱 서비스 (iOS) · App Store 출시',
    'summary': '계획 없이 떠나도 알찬 하루가 되도록, 국도를 달리며 만나는 우연을 관광데이터로 뒷받침하는 즉흥 여행 앱',
    'why': [
        '• 즉흥 여행의 확산',
        '- 목적지 없이 떠나는 예능 프로그램 「풍향중」의 흥행은 국도에서 우연히 만나는 새로움에 대한 수요가 커졌음을 보여줌',
        '• 관광데이터의 가능성',
        '- 관광공사 관광정보의 영업시간·휴무일·장날·사진·연관 관광지를 국도 선형과 현재 위치·진행 방향에 결합',
        '- "지금 이 길 앞에 무엇이 있는가"로 전환',
        '• 기획 방향',
        '- 지도책만으로 나서면 문 닫은 식당, 장이 서지 않는 날, 지나친 뒤 알게 되는 명소로 휴일을 낭비할 위험',
        '- 목적지는 묻지 않되, 그 리스크를 관광데이터로 걸러 우연을 뒷받침하는 앱을 기획',
        '• 기대효과',
        '- 계획 없이 떠나도 알찬 하루: 관광데이터 기반 명소 추천을 통해 헛걸음 감소',
        '- 국도에서 만난 우연이 하루의 여행기로 남아 국도 여행의 경험 축적',
        '- 발길이 대도시 밖 소도시·시장·자연으로 분산되어 지역 관광 활성화에 기여',
    ],
}

FEATURES_LIST = [
    '1. 국도 선택 지도',
    '- 지도 위에 국도 51선 전체 선형(국토부 도로중심선). 내 주변에서 탈 수 있는 길 자동 판정',
    '- 노선별 큐레이션 한 줄: 오늘 장이 서는 길, 발길이 늘어난 길',
    '2. 발견 레이더',
    '- 주행 중: 현재 위치·진행 방향 반경 5km의 검증된 스팟(영업정보·사진 확인)을 카드 한 장으로. 경로가 아니라 위치 기준이라 길을 바꿔도 동작',
    '- 정차 후: 2분 서 있으면 「여기서 앞쪽으로」 앞쪽 10km 후보 3곳 또는 국도로 복귀. 다른 국도로 갈아타도 여행과 기록 유지',
    '3. 오늘만 볼 수 있는 발견 우선',
    '- 장날(전통시장 표준데이터)·일몰(천문연 출몰시각)·축제 기간을 관광정보에 결합',
    '- "지금 아니면 없는 것"을 카드 우선순위 최상단에 배치',
    '4. 내비와 함께 쓰는 주행 중 조작',
    '- 길안내는 티맵·애플 지도. 「들르기」 한 번으로 안내 중에도 목적지 변경 (앱 자체 턴바이턴·ETA 없음)',
    '- 카드는 내비 음성을 끊지 않고 낭독. 놓친 발견은 알림 센터에 보관',
    '5. 여행기 자동 기록',
    '- 하루를 「N번 국도에서 생긴 일」 한 편으로. GPS 포스터·타임라인·공유 카드',
    '- 국도 51선 수집 누적. 계정 없이 기기 안 저장',
]

# 핵심 기능별 흐름도 (최대 5장). 캡처 4장 + 단계 설명 4칸.
FLOWS = [
    {
        'title': '출발 — 국도 선택',
        'desc': ['목적지가 아닌 길을 선택. 지도에서 내 주변의 국도를 고르고 방향만 결정',
                 '길안내는 티맵·애플 지도로 연결하고 출발'],
        'shots': ['1_home.png', 'home_expanded.png', '2_depart.png', 'handoff-t16.png'],
        'steps': [
            ['① 홈 = 지도', '- 국도 51선 파란 선', '- 「여기서 탈 수 있는 길」 + 노선별 큐레이션 한 줄'],
            ['② 51선 전체', '- 시트를 올리면 전체 목록', '- 남북(홀수)·동서(짝수) 필터'],
            ['③ 방향만 선택', '- 「여기서 어느 쪽으로 갈까요?」', '- 북/남 선택, 목적지 입력 없음'],
            ['④ 출발', '- 티맵 / 애플 지도로 길안내 연결', '- 레이더가 켜지고 주행 시작'],
        ],
    },
    {
        'title': '주행 — 발견 레이더',
        'desc': ['달리는 동안 현재 위치·진행 방향 반경 5km의 검증된 스팟을 카드 한 장으로 제시',
                 '내비를 켠 채로도 소리로 먼저 안내, 놓친 발견은 알림에 보관'],
        'shots': ['4_radar.png', '3_card.png', 'onboard3-t6.png', 'myset2-t8.png'],
        'steps': [
            ['① 레이더', '- 내 위치 기준 앞쪽 스팟(유형별 색)', '- 경로를 따르지 않아 길을 바꿔도 동작'],
            ['② 발견 카드', '- 「오늘이 마침 북평민속오일장이에요」', '- 「여기서 약 1.2km」 · 넘기기 / 들르기 / 찜'],
            ['③ 소리·알림', '- 카드 문장을 음성으로 낭독', '- 놓치면 알림 센터에 보관, 선택 시 상세로'],
            ['④ 설정', '- 「앱을 꺼둬도 알림」(백그라운드 위치 옵트인)', '- 「발견 간격」 자주·보통·가끔'],
        ],
    },
    {
        'title': '방문 — 들르기·핸드오프',
        'desc': ['마음이 끌리면 「들르기」 한 번으로 내비의 목적지를 변경. 앱 자체는 길안내를 하지 않음',
                 '들른 곳은 「오늘 들른 곳」 자취로 남고, 「찜」으로 담아 둘 수 있음'],
        'shots': ['3_card.png', 'visit-t21.png', '5_spot.png', 'radar-t26.png'],
        'steps': [
            ['① 들르기', '- 발견 카드의 「들르기」', '- 또는 「찜」으로 나중을 위해 담기'],
            ['② 핸드오프', '- 티맵 / 애플 지도가 그 곳으로 안내', '- 안내 중에도 목적지 변경'],
            ['③ 스팟 상세', '- 관광공사 사진·개요·영업정보', '- 별점 없이 「네이버 후기 보기」 링크만'],
            ['④ 오늘 들른 곳', '- 레이더 아래 자취에 사진으로 기록', '- 하루의 여행기 재료가 됨'],
        ],
    },
    {
        'title': '재출발 — 다음 행선지',
        'desc': ['식사 후 다음 행선지를 정하는 순간 지원. 정차 2분이면 앞쪽 10km 후보 제시',
                 '다른 국도로 갈아타도 여행과 기록 유지'],
        'shots': ['next2-t17.png', 'next2-t22.png', 'switch-t16.png', 'radar-t14.png'],
        'steps': [
            ['① 자동 표시', '- 들른 뒤 2분 정차 시', '- 「여기서 앞쪽으로」 펼침'],
            ['② 앞쪽 후보', '- 10km 안 후보 3곳', '- 「그냥 7번 국도로 돌아가기」'],
            ['③ 길 바꾸기', '- 상단 뱃지 선택 → 「길을 바꿀까요?」', '- 인근 국도로 전환'],
            ['④ 기록 유지', '- 여행은 하루, 국도는 구간(43 → 6번)', '- 거리·들른 곳 그대로'],
        ],
    },
    {
        'title': '종료 — 여행기',
        'desc': ['「오늘 여행 마치기」 선택 시 지나온 길과 들른 곳을 한 편의 여행기로 자동 생성',
                 '포스터 한 장으로 공유. 지나온 국도를 51선 기준으로 누적'],
        'shots': ['radar-t14.png', 'trip-t16.png', 'share_card_8stops.png', 'my-t8.png'],
        'steps': [
            ['① 여행 마치기', '- 레이더의 「오늘 여행 마치기」', '- 한 번으로 하루 종료'],
            ['② 여행기', '- 「EP.6 — 43번 국도에서 생긴 일」', '- 실제 GPS 선 포스터 + 타임라인'],
            ['③ 공유 카드', '- 지도 · 들른 곳 번호 목록 · 「들른 발견 N」', '- 이미지 한 장으로 공유'],
            ['④ 마이', '- 여행기 목록 · 찜', '- 국도 51선 수집 현황'],
        ],
    },
]

TOUR_APIS = [
    ('한국관광공사 국문 관광정보 서비스(KorService2) — 지역기반 관광정보 조회 areaBasedList2',
     ['전국 관광지·음식점·문화시설·쇼핑(5일장·상설시장) 목록을 시군구 단위로 수집',
      '국도 51선 선형 반경 회랑 내 스팟만 적재(19,957건) → 레이더·발견 카드의 후보 데이터']),
    ('국문 관광정보 — 공통정보 조회 detailCommon2 · 소개정보 조회 detailIntro2',
     ['개요·영업시간·휴무일·장날·전화번호 수집 → 신뢰도 게이트(영업정보·사진 확인)의 근거',
      '카드 본문 생성 (예: 「3·8일에만 서는 장이라, 다음 장은 5일 뒤예요」)']),
    ('국문 관광정보 — 이미지정보 조회 detailImage2',
     ['관광공사 사진을 전면 카드·스팟 상세·「오늘 들른 곳」 자취에 원본 그대로(워터마크 포함) 사용',
      '사진이 없는 스팟은 카드로 노출하지 않음']),
    ('국문 관광정보 — 법정동코드 조회 ldongCode2 · 위치기반 관광정보 조회 locationBasedList2',
     ['시군구 코드 순회 수집과 연관 관광지 이름 매칭의 지역 키',
      '위치기반 조회는 회랑 보강·검증에 활용']),
    ('관광지별 연관 관광지 정보 서비스(TarRlteTarService1) — areaBasedList1 (baseYm 지정)',
     ['기준연월 두 시점(예: 202603·202606)을 비교해 "요즘 더 가는 곳"의 변화율 산출',
      '노선 큐레이션(「요즘 이 길에 발길이 늘었어요」)과 「들른 차들은 다음에 ○○로 갔어요」의 근거',
      '두 시점이 없는 노선은 해당 월 연관 순위로 보조하되 문구 구분(「이 길로 다녀간 사람이 많아요」). 별점·후기 미사용']),
]

OTHER_DATA = [
    ('한국천문연구원 출몰시각 정보 OpenAPI (RiseSetInfoService)',
     ['전망 스팟이 있는 0.1° 격자 × 30일의 일몰 시각을 사전 캐시',
      '일몰 40분 전 뷰포인트 카드·알림(「곧 추암 촛대바위에 해가 져요」)의 기준']),
    ('소상공인시장진흥공단 전국전통시장표준데이터 (파일, CSV)',
     ['장날(3·8일 등)을 관광공사 시장 스팟에 결합 → 「오늘이 마침 장날」 카드와 다음 장 안내',
      '사진·개요가 있는 관광공사 스팟에만 결합 (신규 스팟 생성 없음)']),
    ('국토교통부 일반국도 도로중심선 (파일, SHP)',
     ['국도 51선 선형 → 홈 지도 폴리라인, 회랑 판정(스팟 적재 기준), 진출점 계산',
      '여행기의 국도 51선 수집(지나온 점 맵매칭)에 활용']),
]

DIFF = [
    '• 즉흥 여행 트렌드의 제품화',
    '- 「풍향중」처럼 목적지 없이 떠나는 문화에 맞춘 앱. 즉흥은 유지하고 리스크(휴무·비장날·사진 없는 곳)만 데이터로 제거',
    '• 시장에 없는 시점',
    '- 출발 전 계획(여행 플랫폼)도 목적지 검색(내비)도 아닌 "주행 중" 관광정보 제공. 정보는 이동 중에',
    '• 관광공사 데이터의 이동 맥락 재해석',
    '- 장날·일몰·축제 기간을 현재 위치·진행 방향·시각에 결합. 천문연·전통시장·국토부 데이터를 국도 선형 위에서 결합',
    '• 내비의 대체가 아닌 내비 위의 레이어',
    '- 길안내는 티맵·애플 지도, 발견은 본 앱. 안내 중에도 「들르기」로 목적지 변경',
    '• 신뢰 근거의 차별화',
    '- 별점·리뷰 대신 영업정보·사진 검증과 이동 흔적(연관 관광지 두 시점 변화율)',
    '• 자동 기록',
    '- 주행 후 여행기·포스터·국도 51선 수집이 남는 앱. 계정·광고·추적 없음, 정확한 GPS 좌표는 기기 내 보관',
]
PLAN = [
    '• 여행기 공유 → 「남이 달린 길」',
    '- 여행기 공유로 다른 사용자가 같은 길을 선택. 계정 도입으로 보관·팔로우 지원. 별점·댓글 없이 "N명이 달림 · N명이 멈춤" 흔적만',
    '• 사용자 정차 흔적 기반 큐레이션',
    '- 익명 정차 기록으로 "실제로 멈춘 곳" 산출. 리뷰 없이 신뢰를 쌓는 장치',
    '• 음성 조작',
    '- 카드에 음성으로 응답(찜·들르기·넘기기). 핸즈프리 레이더',
    '• 시간 기반 발견 확대',
    '- 축제 기간(관광공사 행사정보)·야간 개장·계절 발견(단풍·벚꽃·해돋이)',
    '• 데이터 갱신·확장',
    '- 수집 파이프라인 상시화, 농산물 직판장·로컬푸드·지역 축제로 소도시 공백 보완, 구간 코스 자동 생성',
    '• Android 확장',
    '- 유지 중인 코드 분기를 활용한 포팅',
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
set_cell(t.cell(3, 1), INTRO['why'], size=12, gap=4)

# 3 핵심기능 목록
t = find_table(S[2]).table
set_cell(t.cell(0, 1), FEATURES_LIST, size=13.5, gap=6)

# 4 이미지
t_sh = find_table(S[3]); t = t_sh.table
set_cell(t.cell(0, 1), '', size=12); set_cell(t.cell(1, 1), '', size=12)
left0 = Emu(t_sh.left).inches + Emu(t.columns[0].width).inches
top0 = Emu(t_sh.top).inches
r0, r1 = Emu(t.rows[0].height).inches, Emu(t.rows[1].height).inches
cw = Emu(t.columns[1].width).inches
if ICON.exists():
    # 양식은 '로고 또는 대표 이미지 1개' — 썸네일 한 장. 링크·문구는 2번 슬라이드에 있다.
    add_shot(S[3], ICON, left0, top0, cw, r0, pad=0.1)
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
    set_cell(head.cell(1, 1), flow['desc'], size=11)
    body_sh = find_table(slide, '표 7'); body = body_sh.table
    left = Emu(body_sh.left).inches; top = Emu(body_sh.top).inches
    colw = [Emu(c.width).inches for c in body.columns]
    rowh = [Emu(r.height).inches for r in body.rows]
    y_img = top + rowh[0]
    x = left
    for i in range(4):
        set_cell(body.cell(1, i), '', size=10)
        set_cell(body.cell(2, i), flow['steps'][i], size=10.5, gap=2)
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
set_cell(t.cell(0, 1), DIFF, size=10.5, gap=2)
set_cell(t.cell(1, 1), PLAN, size=10.5, gap=2)

# 순서: 복제한 흐름도를 6번 슬라이드 뒤로. 5번(지역 특화)은 지운다 — 전국 서비스라 해당 없음.
count = len(prs.slides._sldIdLst)
for k, _ in enumerate(extra):
    move_slide(prs, count - len(extra) + k, 6 + k)   # 원본 흐름도(인덱스 5) 바로 뒤에 차례로
delete_slide(prs, 4)

OUT.parent.mkdir(exist_ok=True)
prs.save(str(OUT))
print('saved', OUT.relative_to(ROOT), '| slides:', len(prs.slides))
if missing: print('MISSING images:', missing)

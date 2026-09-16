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
import json as _json
_meta_p = SHOTS / 'case' / 'meta.json'
CASE = _json.loads(_meta_p.read_text()) if _meta_p.exists() else {'date': '', 'market_day': False}
CASE_LABEL = (f"{CASE['date']} 장날 실제 캡처" if CASE.get('market_day') else f"{CASE['date']} 비장날 캡처 (장날 캡처로 교체 예정)") if CASE.get('date') else '재현 캡처'
CARD_LINE = '「오늘이 마침 북평민속오일장이에요」' if CASE.get('market_day') else '「다음 장은 N일 뒤 · 여기서 약 N km」 (비장날엔 다음 일정을 안내)'

def img(name):
    """스크린샷 이름 → 경로. 스토어 스크린샷 → 추가 캡처 → 골든 순."""
    for base in (SHOTS, SHOTS / 'case', IMG_DIR, ROOT / 'app/test/goldens'):
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
        run.font.bold = True if ((bold_first and i == 0) or head) else False
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
        # ⚠ 그림은 복사하지 않는다 (2026-09-16). 원본에 이미 넣은 캡처까지 딸려 와 새 슬라이드의 그림 아래에
        #   같은 이미지가 다른 크기로 깔렸다 — 셀마다 두 겹이 겹쳐 '배경이 비치는' 것처럼 보였다.
        if sh.shape_type == 13:
            continue
        dst.shapes._spTree.append(copy.deepcopy(sh._element))
    return dst

def move_slide(prs, old_index, new_index):
    sldIdLst = prs.slides._sldIdLst
    ids = list(sldIdLst)
    el = ids[old_index]
    sldIdLst.remove(el)
    sldIdLst.insert(new_index, el)

def add_shot(slide, path, left, top, box_w, box_h, pad=0.06, crop=None):
    """상자(인치) 안에 비율 유지로 가운데 놓는다. crop=(top, bottom) 은 세로 비율로 잘라 핵심만 키운다."""
    from PIL import Image
    import tempfile
    if crop:
        with Image.open(path) as im:
            w0, h0 = im.size
            box = (0, int(h0 * crop[0]), w0, int(h0 * crop[1]))
            tmp = tempfile.NamedTemporaryFile(suffix='.png', delete=False)
            im.crop(box).save(tmp.name); path = pathlib.Path(tmp.name)
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
    'summary': [
        '목적지를 정하지 않고 국도로 떠나는 운전자·동승자를 위한 여행 발견 앱',
        '현재 위치와 진행 방향에 장날·일몰 등 시간 정보를 결합해 지금 들를 만한 곳을 알려주고,',
        '선택한 장소는 기존 내비게이션으로 안내',
        '길안내는 내비가, 뜻밖의 발견은 P의여행이.',
    ],
    'why': [
        '• 「풍향중」처럼, 계획 없이 떠나는 여행을 일상에서도',
        '- 즉흥 여행의 매력은 예상하지 못한 발견. 하지만 직접 떠나면 어디에 들를지, 오늘 장이 서는지 다시 찾아야 함',
        '• 해결',
        '- 현재 위치·진행 방향에 장날·일몰 정보를 결합해 지금 들를 이유를 먼저 안내. 계획하는 수고는 줄이고 우연히 발견하는 즐거움은 남김',
        '- 사진과 추천 근거가 되는 정보를 갖춘 장소만 노출. 장날·휴무일은 안내하되 점포별 영업시간·임시휴무는 방문 전 확인 필요(앱에도 같은 안내)',
        '• 효과와 검증',
        '- 목적지까지 통과하던 여행자가 계획에 없던 지역의 장소에 한 번 더 멈추게 함',
        '- 정차 감지로 방문 후보를 기록하고, 여행 후 사용자 확인으로 실제 방문과 계획에 없던 방문 여부를 검증 (기기 내 집계·동의 기반)',
    ],
}

FEATURES_LIST = [
    '1. 국도 선택 지도',
    '- 지도 위에 국도 51선 전체 선형(국토부 도로중심선). 내 주변에서 탈 수 있는 길 자동 판정',
    '- 노선별 큐레이션 한 줄: 오늘 장이 서는 길, 함께 찾는 곳이 많은 길(연관 관광지 순위. 최근 두 시점이 있으면 순위 변화를 정렬에 참고)',
    '2. 발견 레이더 — 지금 지나가는 길 앞의 들를 이유',
    '- 주행 중: 현재 위치·진행 방향 반경 5km에서 사진과 추천 근거(소개·영업정보)를 갖춘 장소만 카드 한 장으로. 거리는 직선거리(도로 거리·소요 시간 아님)',
    '- 장날·휴무일은 안내하되 점포별 영업시간·임시휴무는 방문 전 확인 필요. 정차 2분이면 「여기서 앞쪽으로」 앞쪽 10km 후보 3곳, 다른 국도로 갈아타도 기록 유지',
    '3. 오늘만 볼 수 있는 발견 우선',
    '- 장날(전통시장 표준데이터)·일몰(천문연 출몰시각)·이번 주에 끝나는 행사(관광공사 행사정보)를 관광정보에 결합',
    '- "지금 아니면 없는 것"을 카드 우선순위 최상단에 배치. 비장날에는 다음 장날을 안내',
    '4. 내비와 함께 쓰는 안전한 사용',
    '- 이용 원칙: 이동 중에는 음성으로 발견을 전달하고, 장소 선택은 동승자 또는 안전하게 정차한 운전자가 진행',
    '- 구현된 장치: 내비 음성을 끊지 않는 낭독, 놓친 발견은 알림 센터에 보관, 정차를 감지해야 「여기서 앞쪽으로」 표시, 카드 간격으로 재촉 방지. 「들르기」 선택 시 티맵·애플 지도가 안내(앱 자체 턴바이턴·ETA 없음)',
    '5. 여행기 자동 기록',
    '- 하루를 「N번 국도에서 생긴 일」 한 편으로. GPS 포스터·타임라인·공유 카드',
    '- 국도 51선 수집 누적. 계정 없이 기기 안 저장',
]

# 핵심 기능별 흐름도 (최대 5장). 캡처 4장 + 단계 설명 4칸.
FLOWS = [
    {
        'title': '출발 — 국도 선택',
        'desc': ['목적지가 아닌 길을 선택. 지도에서 내 주변의 국도를 고르고 방향만 결정',
                 '앱이 현재 위치에서 가장 가까운 그 국도 위 지점(진입 지점)을 내비 목적지로 전달'],
        'shots': ['1_home.png', 'home_expanded.png', '2_depart.png', 'handoff-t16.png'],
        'steps': [
            ['① 홈 = 지도', '- 국도 51선 파란 선', '- 「여기서 탈 수 있는 길」 + 노선별 큐레이션 한 줄'],
            ['② 51선 전체', '- 시트를 올리면 전체 목록', '- 남북(홀수)·동서(짝수) 필터'],
            ['③ 방향만 선택', '- 「여기서 어느 쪽으로 갈까요?」', '- 북/남 선택, 목적지 입력 없음'],
            ['④ 출발', '- 진입 지점을 내비 목적지로 전달', '- 티맵 / 애플 지도가 그 지점까지 안내'],
        ],
    },
    {
        'title': '주행 — 발견 레이더',
        'desc': ['달리는 동안 현재 위치·진행 방향 반경 5km에서 영업정보·사진을 확인할 수 있는 장소를 카드 한 장으로',
                 '이동 중에는 음성으로 전달, 놓친 발견은 알림 센터에 보관. 대표 사례: 7번 국도 · 북평민속오일장(3·8일 장)'],
        'shots': ['4_radar.png', ('case-card.png', (0.34, 0.82)), 'notif-lock.png', 'notif-sunset.png'],
        'steps': [
            ['① 레이더', '- 내 위치 기준 앞쪽 스팟(유형별 색)', '- 경로를 따르지 않아 길을 바꿔도 동작'],
            ['② 장날 카드 (확대)', f'- {CARD_LINE}', f'- 「여기서 약 N km」는 직선거리 · {CASE_LABEL}'],
            ['③ 알림 (실기기 녹화 프레임)', '- 잠금화면 알림 「오늘이 마침 경안시장이에요」 — 2026-09-13 실주행', '- 카드 음성 낭독은 데모 영상 「덕풍공원」 카드 구간에서 확인'],
            ['④ 내비 위 알림 배너 (실기기 녹화 프레임)', '- 티맵 안내 중 「곧 하남 나무고아원에 해가 져요」 — 2026-09-13 실주행', '- 설정에서 「앱을 꺼둬도 알림」(백그라운드 위치 옵트인)·「발견 간격」 조절'],
        ],
    },
    {
        'title': '방문 — 들르기·핸드오프',
        'desc': ['정차한 운전자 또는 동승자가 「들르기」를 선택하면 내비의 목적지를 그 장소로 변경. 앱 자체는 길안내를 하지 않음',
                 '들른 곳은 「오늘 들른 곳」 자취로 남음. 같은 사례(북평민속오일장)로 이어짐'],
        'shots': [('case-card.png', (0.45, 1.0)), ('case-handoff.png', (0.4, 1.0)), 'case-spot.png', 'case-trail.png'],
        'steps': [
            ['① 들르기 (확대)', '- 카드 아래 넘기기 / 들르기 / 찜', '- 또는 「찜」으로 나중을 위해 담기'],
            ['② 핸드오프 (확대)', '- 「북평민속오일장」 → 티맵 / 애플 지도', f'- 안내 중에도 목적지 변경 · {CASE_LABEL}'],
            ['③ 스팟 상세', '- 관광공사 사진·개요·영업정보·장날', '- 별점 없이 「네이버 후기 보기」 링크만'],
            ['④ 오늘 들른 곳', '- 레이더 아래 자취에 사진으로 기록', '- 하루의 여행기 재료가 됨'],
        ],
    },
    {
        'title': '재출발 — 다음 행선지',
        'desc': ['식사 후 다음 행선지를 정하는 순간 지원. 정차 2분을 감지하면 앞쪽 10km 후보 제시',
                 '다른 국도로 갈아타도 여행과 기록 유지'],
        'shots': ['next2-t17.png', 'next2-t22.png', 'switch-t16.png', 'radar-t14.png'],
        'steps': [
            ['① 자동 표시', '- 들른 뒤 2분 정차를 감지하면', '- 「여기서 앞쪽으로」 펼침 (달리는 중엔 열리지 않음)'],
            ['② 앞쪽 후보', '- 10km 안 후보 3곳', '- 「그냥 7번 국도로 돌아가기」'],
            ['③ 길 바꾸기', '- 상단 뱃지 선택 → 「길을 바꿀까요?」', '- 인근 국도로 전환'],
            ['④ 기록 유지', '- 여행은 하루, 국도는 구간(43 → 6번)', '- 거리·들른 곳 그대로'],
        ],
    },
    {
        'title': '종료 — 여행기',
        'desc': ['「오늘 여행 마치기」 선택 시 지나온 길과 들른 곳을 한 편의 여행기로 자동 생성',
                 '포스터 한 장으로 공유. 지나온 국도를 51선 기준으로 누적'],
        'shots': ['radar-t14.png', 'case-trip.png', 'share_card_8stops.png', 'my-t8.png'],
        'steps': [
            ['① 여행 마치기', '- 레이더의 「오늘 여행 마치기」', '- 한 번으로 하루 종료'],
            ['② 여행기', '- 「동해 바닷길에서 생긴 일」 (7번 국도)', f'- GPS 선 포스터 + 들른 곳(북평민속오일장) · {CASE_LABEL}'],
            ['③ 공유 카드 (예시)', '- 지도 · 들른 곳 번호 목록 · 「들른 발견 N」', '- 이미지 한 장으로 공유'],
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
     ['같은 방문자가 함께 방문하는 경향이 있는 관광지의 순위 데이터. 스팟 상세 「함께 찾은 곳」과 노선 큐레이션 한 줄(「함께 찾는 곳이 많아요」)에 활용',
      '기준연월 두 시점(예: 202603·202606)이 모두 있으면 이전 기준월보다 연관 순위가 오른 관광지를 추천 정렬에 참고. 사용자 문구는 「최근에도 함께 찾는 곳이 많아요」로, 증가를 주장하지 않음',
      '방문자 수·증가량·이동 순서·차량 이용은 이 데이터로 알 수 없어 그렇게 표현하지 않음. 별점·후기 미사용']),
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
    '• 목적지가 아니라 이동 중의 발견을 돕는다',
    '- 장소를 미리 정하는 대신, 현재 위치와 진행 방향에서 들를 후보를 제시. 길을 바꿔도 그대로 동작',
    '• 가까운 곳을 넘어 "지금 들를 이유"를 알려준다',
    '- 장날·일몰·이번 주에 끝나는 행사 등 시간 정보를 결합해, 같은 장소라도 시점에 따라 추천 의미를 달리함',
    '• 기존 내비와 역할을 나눈다',
    '- 길안내를 다시 만들지 않고 발견과 방문 기록에 집중. 「들르기」 선택 시 티맵·애플 지도가 안내하고, 하루가 여행기로 남음',
]
PLAN = [
    '• 핵심 가치 검증',
    '- 추천 후 「들르기」 선택률, 정차 감지 기반 방문 여부, 여행 후 질문으로 "계획에 없던 지역 방문"이 실제로 발생하는지 확인 (기기 내 집계·동의 기반)',
    '• 안전한 사용 상황 강화',
    '- 음성으로 카드에 응답(찜·들르기·넘기기)해 이동 중 화면 조작 없이 사용. 정차 감지 기준 정교화',
    '• 데이터 신뢰도 개선',
    '- 수집 파이프라인 상시화로 갱신 지연 축소, 임시휴무·정보 불확실 장소의 처리 기준 명시, 사용자 정차 흔적으로 "실제로 멈춘 곳" 보강',
    '• 시간 기반 발견 확대',
    '- 축제 기간 전체(현재는 이번 주에 끝나는 행사만)·야간 개장·계절 발견(단풍·벚꽃·해돋이)',
    '• 지역 확장·공유',
    '- 농산물 직판장·로컬푸드·지역 축제 데이터로 소도시 공백 보완, 여행기 공유 → 「남이 달린 길」(별점·댓글 없이 흔적만)',
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
set_cell(t.cell(2, 1), INTRO['summary'], size=13, bold_first=True)
set_cell(t.cell(3, 1), INTRO['why'], size=11, gap=3)

# 3 핵심기능 목록
t = find_table(S[2]).table
set_cell(t.cell(0, 1), FEATURES_LIST, size=12.5, gap=5)

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
        shot = flow['shots'][i]
        name, crop = (shot, None) if isinstance(shot, str) else shot
        p = img(name)
        if p: add_shot(slide, p, x, y_img, colw[i], rowh[1], pad=0.08, crop=crop)
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

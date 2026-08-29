/**
 * TourAPI 위치기반관광정보 → spots 적재.
 *
 * 실측(2026-08-29)으로 확정된 것:
 *  - 엔드포인트는 **KorService2**
 *  - 목록에는 개요·영업시간이 없다. detailCommon2 / detailIntro2를 따로 불러야 한다
 *  - 그렇게 채우면 신뢰도 게이트(60) 통과율이 88%다
 *  - 전화번호는 거의 안 온다 (8건 중 1건) — 배점 15는 사실상 잘 안 붙는다
 *
 * ⚠ 별점·후기를 가져오지 않는다 (원칙 3). TourAPI에 그런 필드가 있어도 쓰지 않는다.
 * ⚠ exit_geom·exit_frac·detour_min은 노선 선형이 있어야 계산된다.
 *   없으면 null로 둔다 — 지어내지 않는다.
 *
 * 실행: cd pipeline && npm run fetch:spots
 */

import { supabase } from './lib/supabase.js';

const KEY = process.env.TOURAPI_KEY?.trim();
const BASE = 'https://apis.data.go.kr/B551011/KorService2';
const COMMON = `MobileOS=ETC&MobileApp=PTrip&_type=json`;

/**
 * 데모 구간 시군구 — **법정동 코드**로 조회한다.
 *
 * ⚠ 구 areaCode(32=강원) / sigunguCode로 조회하면 안 된다.
 *   강원특별자치도 전환 때 areacode가 빈 레코드가 생겼고, **묵호등대가 거기 걸린다.**
 *   같은 동해시가 구 코드로는 48건, 법정동 코드로는 116건이다.
 *   위치기반(locationBasedList2)도 같은 이유로 묵호등대를 안 준다 — 그래서 안 쓴다.
 */
const SIGUNGU = [
  { name: '삼척시', regn: '51', signgu: '230' },
  { name: '동해시', regn: '51', signgu: '170' },
  { name: '강릉시', regn: '51', signgu: '150' },
];

/**
 * 7번 국도 해안 구간의 대략 선형. 이 선에서 [CORRIDOR_KM] 안쪽만 담는다.
 * 강릉시는 내륙까지 넓어서 시군구 전체를 담으면 국도와 상관없는 스팟이 섞인다.
 * ⚠ 손으로 찍은 근사선이다. build-routes가 실제 선형을 넣으면 그걸로 바꾼다.
 */
const CORRIDOR = [
  [129.1650, 37.4500], // 삼척
  [129.1143, 37.5245], // 동해
  [129.1150, 37.5520], // 묵호
  [129.0530, 37.6060], // 망상
  [129.0300, 37.6600], // 옥계
  [129.0340, 37.6900], // 정동진
  [128.8960, 37.7550], // 강릉
];
const CORRIDOR_KM = Number(process.env.CORRIDOR_KM ?? 10);

/** 점과 선분 사이 거리(km). 위도 37도 부근이라 평면 근사로 충분하다. */
function distToCorridorKm(lat: number, lng: number): number {
  const KX = 88.0; // 경도 1도 ≈ 88km (위도 37도)
  const KY = 111.0;
  let best = Infinity;
  for (let i = 0; i < CORRIDOR.length - 1; i++) {
    const [x1, y1] = CORRIDOR[i];
    const [x2, y2] = CORRIDOR[i + 1];
    const ax = (lng - x1) * KX, ay = (lat - y1) * KY;
    const bx = (x2 - x1) * KX, by = (y2 - y1) * KY;
    const len2 = bx * bx + by * by;
    const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, (ax * bx + ay * by) / len2));
    const dx = ax - bx * t, dy = ay - by * t;
    best = Math.min(best, Math.hypot(dx, dy));
  }
  return best;
}

/** TourAPI contenttypeid → 우리 spot_type. 25(여행코스)는 우리 코스와 겹쳐서 버린다. */
const TYPE_MAP: Record<string, string> = {
  '12': 'attraction', // 관광지 — cat1이 A01(자연)이면 아래에서 view로 바꾼다
  '14': 'culture',    // 문화시설
  '15': 'attraction', // 축제공연행사 — events 행도 같이 만든다
  '28': 'attraction', // 레포츠
  '32': 'stay',       // 숙박
  '38': 'attraction', // 쇼핑 — ⚠ 전통시장은 표준데이터가 정본이라 여기서 market으로 만들지 않는다
  '39': 'food',       // 음식점
};

type Item = Record<string, string>;

/** 3,000콜을 치면 몇 개는 반드시 늦는다. 하나가 늦다고 전체를 죽이지 않는다. */
let failures = 0;

async function api(path: string, params: string, tries = 3): Promise<Item[]> {
  const url = `${BASE}/${path}?serviceKey=${KEY}&${COMMON}&${params}`;
  for (let n = 1; n <= tries; n++) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(15_000) });
      const text = await res.text();
      // 키·쿼터 문제는 재시도해도 소용없다. 즉시 멈춰서 원인을 보게 한다.
      if (/SERVICE_KEY_IS_NOT_REGISTERED|LIMITED_NUMBER|SERVICE_ACCESS_DENIED/i.test(text)) {
        throw new Error(`TourAPI 거부: ${text.slice(0, 160)}`);
      }
      const item = JSON.parse(text)?.response?.body?.items?.item;
      if (!item) return [];
      return Array.isArray(item) ? item : [item];
    } catch (e) {
      if (e instanceof Error && e.message.startsWith('TourAPI 거부')) throw e;
      if (n === tries) {
        failures++;
        return [];
      }
      await new Promise((r) => setTimeout(r, 400 * n));
    }
  }
  return [];
}

/** 목록 — 시군구 전체. 페이지를 끝까지 넘긴다. */
async function listSigungu(regn: string, signgu: string): Promise<Item[]> {
  const out: Item[] = [];
  for (let page = 1; page <= 40; page++) {
    const rows = await api(
      'areaBasedList2',
      `lDongRegnCd=${regn}&lDongSignguCd=${signgu}&numOfRows=100&pageNo=${page}`,
    );
    out.push(...rows);
    if (rows.length < 100) break;
  }
  return out;
}

/** 영업시간 필드는 유형마다 이름이 다르다. 하나라도 차 있으면 인정한다. */
const HOUR_FIELDS = [
  'usetime', 'usetimefestival', 'opentimefood', 'opentime',
  'checkintime', 'playtime', 'usetimeculture', 'usetimeleports',
];

function openHoursOf(intro: Item | undefined): string | null {
  if (!intro) return null;
  for (const f of HOUR_FIELDS) {
    const v = intro[f]?.trim();
    if (v) return v.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  }
  return null;
}

/**
 * trust_score — TECH_SPEC §2 배점표.
 * 대표사진 35 / 추가사진 3장+ 10 / 전화 15 / 영업시간 20 / 번지까지 주소 10 / 개요 10
 */
function trustScore(s: {
  image: string | null;
  photoCount: number;
  tel: string | null;
  openHours: string | null;
  addr: string | null;
  overview: string | null;
}): number {
  let n = 0;
  if (s.image) n += 35;
  if (s.photoCount >= 3) n += 10;
  if (s.tel) n += 15;
  if (s.openHours) n += 20;
  // '번지까지' = 숫자가 들어간 주소. 시·군까지만 있는 주소는 헛걸음을 못 막는다.
  if (s.addr && /\d/.test(s.addr)) n += 10;
  if (s.overview && s.overview.length > 30) n += 10;
  return n;
}

function clean(html: string | undefined): string | null {
  if (!html) return null;
  const t = html.replace(/<[^>]+>/g, ' ').replace(/&[a-z]+;/g, ' ').replace(/\s+/g, ' ').trim();
  return t || null;
}

async function main() {
  if (!KEY) throw new Error('TOURAPI_KEY가 비어 있습니다. .env를 확인하세요.');
  const db = supabase();

  // 1) 시군구별 전체 목록 → 국도 회랑 10km 안쪽만 남긴다.
  const seen = new Map<string, Item>();
  for (const sg of SIGUNGU) {
    const rows = await listSigungu(sg.regn, sg.signgu);
    let kept = 0;
    for (const r of rows) {
      if (!r.contentid || seen.has(r.contentid)) continue;
      const lat = Number(r.mapy), lng = Number(r.mapx);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
      if (distToCorridorKm(lat, lng) > CORRIDOR_KM) continue;
      seen.set(r.contentid, r);
      kept++;
    }
    console.log(`  ${sg.name}: ${rows.length}건 → 회랑 ${CORRIDOR_KM}km 안 ${kept}건`);
  }
  console.log(`\n합계 ${seen.size}건. 상세를 채웁니다…`);

  // 2) 상세를 채우고 점수를 매긴다.
  //    스팟 하나에 3콜이라 순차로 돌리면 1,000건에 15분이 넘는다. 묶어서 동시에 친다.
  const spots: Record<string, unknown>[] = [];
  const events: { contentid: string; title: string; start: string; end: string }[] = [];
  let done = 0;

  // ⚠ TourAPI는 **일일 요청 제한**이 있다. 스팟 하나에 2~3콜이라 1,000건이면 금방 닿는다.
  //   이미 채운 건 건너뛰어 다음 날 이어받는다. RESET=1이면 전부 다시 받는다.
  const { data: existing } = await db.from('spots').select('tourapi_contentid').gt('trust_score', 0);
  const doneIds = new Set((existing ?? []).map((r) => r.tourapi_contentid as string));
  const reset = process.env.RESET === '1';

  const targets = [...seen].filter(
    ([id, i]) => TYPE_MAP[i.contenttypeid] && (reset || !doneIds.has(id)),
  );
  console.log(
    `  대상 ${targets.length}건` +
      (doneIds.size && !reset ? ` (이미 채운 ${doneIds.size}건 건너뜀 — RESET=1로 재수집)` : ''),
  );
  if (targets.length === 0) {
    console.log('\n· 새로 받을 게 없습니다.');
    return;
  }

  async function fill([id, item]: [string, Item]) {
    const type = TYPE_MAP[item.contenttypeid]!;

    // ⚠ 목록 응답에 이미 사진(84%)·주소(99%)·전화가 들어 있다.
    //   detailCommon2는 **개요 하나 때문에** 부르는 셈인데, 개요는 게이트 10점이라
    //   있으나 없으나 통과 여부가 거의 안 갈린다. 일일 요청 제한이 빠듯하니 기본으로 안 부른다.
    //   개요는 fetch:overview 단계에서 게이트를 통과한 스팟만 따로 채운다.
    const introRows = await api('detailIntro2', `contentId=${id}&contentTypeId=${item.contenttypeid}`);
    const intro = introRows[0];

    const addr = (item.addr1 || '').trim() || null;
    const tel = (item.tel || '').trim() || null;
    // ⚠ TourAPI는 http://로 준다. iOS ATS가 평문 HTTP를 막아 사진이 안 뜬다.
    //   같은 호스트가 https로도 주므로 적재할 때 올려둔다.
    const image = ((item.firstimage || '').trim() || null)?.replace(/^http:\/\//, 'https://') ?? null;
    const openHours = openHoursOf(intro);

    // 추가사진(10점)은 게이트를 가를 때만 확인한다. 일일 요청 제한을 아껴야 한다.
    const base = trustScore({ image, photoCount: 0, tel, openHours, addr, overview: null });
    const photoCount =
      base >= 50 && base < 60 ? (await api('detailImage2', `contentId=${id}&imageYN=Y`)).length : 0;

    // 자연관광지는 뷰포인트로 다룬다 — 일몰 타이밍 가중치(§3.1)가 걸리는 유형이다.
    const cat1 = item.cat1 || '';
    const finalType = type === 'attraction' && cat1 === 'A01' ? 'view' : type;

    const lat = Number(item.mapy);
    const lng = Number(item.mapx);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;

    spots.push({
      tourapi_contentid: id,
      type: finalType,
      name: item.title?.trim(),
      lat,
      lng,
      geom: `SRID=4326;POINT(${lng} ${lat})`,
      addr,
      tel,
      image_url: image,
      photo_count: photoCount,
      // ⚠ overview는 넣지 않는다. null로 upsert하면 이미 채운 개요를 지운다.
      open_hours: openHours,
      tags: [],
      trust_score: trustScore({ image, photoCount, tel, openHours, addr, overview: null }),
      // ⚠ exit_geom·exit_frac·detour_min은 노선 선형이 있어야 계산된다.
      //   build-routes가 geom을 채운 뒤 별도 단계에서 메운다.
      updated_at: new Date().toISOString(),
    });

    if (item.contenttypeid === '15' && intro?.eventstartdate && intro?.eventenddate) {
      events.push({
        contentid: id,
        title: item.title?.trim() ?? '',
        start: intro.eventstartdate,
        end: intro.eventenddate,
      });
    }

    if (++done % 100 === 0) console.log(`    ${done}/${targets.length}`);
  }

  // ⚠ 동시 8개로 돌렸더니 **초당 요청 수 초과**로 거부당했다
  //   (LIMITED_NUMBER_OF_SERVICE_REQUESTS_PER_SECOND_EXCEEDS_ERROR).
  //   일일 할당량과 다른 제한이라 재시도로는 못 넘는다 — 속도를 줄이는 수밖에 없다.
  //   4개씩 + 묶음 사이 250ms면 초당 약 16콜이다.
  const LANES = 4;
  const GAP_MS = 250;
  for (let i = 0; i < targets.length; i += LANES) {
    // 한 건이 터져도 나머지는 간다.
    await Promise.all(
      targets.slice(i, i + LANES).map((t) =>
        fill(t).catch((e) => {
          if (e instanceof Error && e.message.startsWith('TourAPI 거부')) throw e;
          failures++;
        }),
      ),
    );
    if (i + LANES < targets.length) await new Promise((r) => setTimeout(r, GAP_MS));
  }
  if (failures) console.log(`  ⚠ 응답을 못 받은 요청 ${failures}건 — 그만큼 항목이 비어 있을 수 있다`);

  // 3) 적재
  const { error } = await db
    .from('spots')
    .upsert(spots, { onConflict: 'tourapi_contentid' })
    .select('id, tourapi_contentid');
  if (error) throw new Error(`spots 적재 실패: ${error.message}`);

  // 행사는 spot이 생긴 뒤에 붙인다.
  if (events.length) {
    const { data: rows } = await db
      .from('spots')
      .select('id, tourapi_contentid')
      .in('tourapi_contentid', events.map((e) => e.contentid));
    const byContent = new Map((rows ?? []).map((r) => [r.tourapi_contentid, r.id]));
    const eventRows = events
      .filter((e) => byContent.has(e.contentid))
      .map((e) => ({
        spot_id: byContent.get(e.contentid),
        title: e.title,
        start_date: `${e.start.slice(0, 4)}-${e.start.slice(4, 6)}-${e.start.slice(6, 8)}`,
        end_date: `${e.end.slice(0, 4)}-${e.end.slice(4, 6)}-${e.end.slice(6, 8)}`,
      }));
    if (eventRows.length) {
      const { error: e2 } = await db.from('events').insert(eventRows);
      if (e2) console.log(`  ⚠ events 적재 실패: ${e2.message}`);
      else console.log(`  행사 ${eventRows.length}건`);
    }
  }

  // 4) 보고 — 게이트 통과율이 M1의 합격선이다.
  const pass = spots.filter((s) => (s.trust_score as number) >= 60).length;
  const byType = spots.reduce<Record<string, number>>((m, s) => {
    m[s.type as string] = (m[s.type as string] ?? 0) + 1;
    return m;
  }, {});
  console.log(`\n✓ spots ${spots.length}건 적재`);
  console.log(`  유형: ${Object.entries(byType).map(([k, v]) => `${k} ${v}`).join(' · ')}`);
  console.log(`  신뢰도 게이트(60) 통과 ${pass}건 (${Math.round((pass / spots.length) * 100)}%)`);
  console.log(`  전화 보유 ${spots.filter((s) => s.tel).length}건 · 사진 보유 ${spots.filter((s) => s.image_url).length}건`);
  console.log('\n· 개요는 아직 비어 있다 — `npm run fetch:overview`로 게이트 통과분만 채운다.');
  console.log('· exit_frac·detour_min은 별도 단계에서 계산한다.');
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

/**
 * TourAPI 지역기반관광정보 → spots 적재. **전국.**
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
 * 전국 수집 (2026-08-30 출시 전환):
 *  - 시도 17개를 순회한다. 시군구까지 내려가지 않아도 페이지 총량은 같다
 *  - 회랑 판정은 **`near_routes` RPC**가 한다. 손으로 찍은 좌표선은 전국에 못 쓴다 —
 *    이미 `routes.geom`에 51선 실제 선형이 있다
 *  - 목록도 상세도 할당량이다. 목록은 `data/candidates.json`에 캐시하고,
 *    상세는 이미 채운 건 건너뛴다 (둘 다 중단·재개를 전제로 짰다)
 *
 * ⚠ **개발계정으로는 못 끝낸다.** 전국이면 상세만 수만 콜이다 —
 *   data.go.kr 운영계정이 있어야 한다 (ROADMAP M6).
 * ⚠ 첫 실행에서 **'⚠ 0건 — 코드 확인'**이 뜨는 시도가 있으면 법정동 시도 코드가
 *   바뀐 것이다. 조용히 넘어가면 그 지역이 통째로 빈다.
 *
 * 실행: cd pipeline && npm run fetch:spots
 *       REGIONS=51,47 npm run fetch:spots   # 시도를 좁혀서
 *       RELIST=1 ...                        # 목록 캐시 무시하고 새로 받기
 *       RESET=1 ...                         # 상세까지 전부 다시
 */

import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

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
const REGIONS: { name: string; regn: string }[] = [
  // ⚠ **제주는 없다** (2026-09-03). `routes` 51선은 본토 기준이라 제주 노선이 없고,
  //   회랑 판정이 2,144건을 전부 버린다. 목록 콜만 태우는 셈이라 아예 안 돈다.
  //   제주 국도가 생기면 `{ name: '제주특별자치도', regn: '50' }` 를 되살린다.
  { name: '서울특별시', regn: '11' },
  { name: '부산광역시', regn: '26' },
  { name: '대구광역시', regn: '27' },
  { name: '인천광역시', regn: '28' },
  { name: '대전광역시', regn: '30' },
  { name: '울산광역시', regn: '31' },
  // ⚠ 세종만 **5자리**다. '36'은 0건을 준다.
  { name: '세종특별자치시', regn: '36110' },
  { name: '경기도', regn: '41' },
  { name: '충청북도', regn: '43' },
  { name: '충청남도', regn: '44' },
  // ⚠ 광주(29)와 전라남도(46)가 **통합돼 코드가 12로 바뀌었다** (2026-09-03 확인).
  //   옛 코드는 둘 다 0건을 준다 — 3,692건이 통째로 빠져 있었다.
  { name: '전남광주통합특별시', regn: '12' },
  { name: '경상북도', regn: '47' },
  { name: '경상남도', regn: '48' },
  { name: '강원특별자치도', regn: '51' },
  { name: '전북특별자치도', regn: '52' },
];

/**
 * 국도 회랑 반경(km). 이 안쪽 스팟만 상세를 받는다.
 *
 * **3.5km인 이유**: 앱이 쓰는 상한이 거기다 (2026-09-03).
 * `detour_min = ceil(km / 40 * 60) * 2` 이고 레이더·코스·훑어보기가 전부
 * `detour_min <= 10` 으로 거른다 → `km <= 3.33`. 그 밖은 받아도 화면에 안 뜬다.
 * 0.17km는 선형 오차 여유다.
 *
 * ⚠ 전에는 10이었다. 반경 20km를 훑던 동승자 모드(DR-05) 때문이었는데
 *   그 기능을 지웠다 (2026-09-03). 이제 넓게 받을 이유가 없다.
 * ⚠ 상세는 **1건당 1콜**이다. 회랑 밖까지 받으면 할당량이 몇 배로 든다.
 * ⚠ 판정은 `near_routes` RPC가 한다 — 손으로 찍은 좌표선을 전국에 쓸 수는 없다.
 *   실제 `routes.geom` 51선을 쓴다.
 */
const CORRIDOR_KM = Number(process.env.CORRIDOR_KM ?? 3.5);

/** 좁혀 돌 때. `REGIONS=51,47 npm run fetch:spots` */
const ONLY = (process.env.REGIONS ?? '')
  .split(',')
  .map((x) => x.trim())
  .filter(Boolean);

/**
 * 목록 캐시. **목록 조회도 할당량이다** — 전국이면 수천 페이지라
 * 다시 돌 때마다 새로 받으면 상세를 받을 몫이 남지 않는다.
 * `RELIST=1`이면 무시하고 새로 받는다.
 */
const CACHE = join(import.meta.dirname, 'data', 'candidates.json');

/** TourAPI contenttypeid → 우리 spot_type. 25(여행코스)는 우리 코스와 겹쳐서 버린다. */
const TYPE_MAP: Record<string, string> = {
  '12': 'attraction', // 관광지 — cat1이 A01(자연)이면 아래에서 view로 바꾼다
  '15': 'attraction', // 축제공연행사 — events 행도 같이 만든다
  '28': 'attraction', // 레포츠 — 캠핑장·낚시터·패러글라이딩
  '32': 'stay',       // 숙박 — CO-06 거점 후보
  '39': 'food',       // 음식점
};

/**
 * 안 받는 유형 (2026-09-03 결정). 지우지 말고 **왜 뺐는지** 남긴다 —
 * 되살릴 때 같은 판단을 다시 하게 하려고.
 *
 * - `38` 쇼핑 (10,743건, 전체의 33%)
 *   실체가 **백화점·아울렛 안의 개별 브랜드 매장**이었다.
 *   "올리브영 송리단길점" · "펜디 현대백화점 압구정본점" · "다이소 대구산격유통단지점".
 *   아울렛 25% · 백화점 15% · 마트 5%. "지나치기엔 아까운 것들"이 아니다.
 *   ⚠ 전통시장은 여기서 안 와도 된다 — 표준데이터(`markets`)가 정본이다.
 *
 * - `14` 문화시설 (2,161건)
 *   박물관·미술관이 47%로 남길 만했지만 **빼기로 했다**.
 *   나머지는 도서관·구청 수련관·대학 체육관이다.
 *   되살리려면 `'14': 'culture'` 한 줄이면 된다.
 */
const DROPPED_TYPES = ['38', '14'] as const;

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

/**
 * 목록 — 시도 전체. 페이지를 끝까지 넘긴다.
 *
 * ⚠ 전에는 `page <= 40`으로 잘렸다. 100건씩이라 **시도당 4,000건이 상한**이었고,
 *   서울(8,007)·경기(9,472)·강원(4,762)에서 **10,241건(22%)이 조용히 빠졌다**.
 *   주석은 '끝까지 넘긴다'고 되어 있었다 (2026-09-03 발견).
 *   이제 마지막 페이지까지 간다 — 끝은 `rows.length < 100`이 알려준다.
 * ⚠ 폭주 방어로 상한은 남겨두되, **닿으면 알린다.** 조용히 자르지 않는다.
 */
const MAX_PAGES = 500;

async function listRegion(name: string, regn: string): Promise<Item[]> {
  const out: Item[] = [];
  let page = 1;
  for (; page <= MAX_PAGES; page++) {
    const rows = await api(
      'areaBasedList2',
      `lDongRegnCd=${regn}&numOfRows=100&pageNo=${page}`,
    );
    out.push(...rows);
    if (rows.length < 100) break;
  }
  if (page > MAX_PAGES) {
    console.log(`  ⚠ ${name}(${regn}) ${MAX_PAGES}페이지 상한에 닿았다 — 뒤가 잘렸을 수 있다`);
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

  // 1) 시도별 전체 목록 → 국도 회랑 안쪽만 남긴다.
  //    ⚠ 목록도 상세도 할당량이다. 목록은 캐시하고, 회랑 판정으로 상세 대상을 줄인다.
  const regions = ONLY.length ? REGIONS.filter((r) => ONLY.includes(r.regn)) : REGIONS;
  const seen = new Map<string, Item>();

  /**
   * 캐시는 **회랑 폭까지 같이 적는다.**
   *
   * ⚠ 캐시는 이미 회랑으로 걸러진 결과다. `CORRIDOR_KM`을 바꾸고 옛 캐시를 그대로 쓰면
   *   조용히 옛 기준으로 돈다 — 10km로 받아둔 걸 3.5km인 줄 알고 쓰게 된다.
   *   폭이 다르면 캐시를 버리고 다시 받는다.
   */
  type Cache = { corridorKm: number; regions: string[]; items: Record<string, Item> };
  const raw = !process.env.RELIST && existsSync(CACHE)
    ? (JSON.parse(readFileSync(CACHE, 'utf-8')) as Partial<Cache>)
    : null;
  const usable = Boolean(raw?.items) && raw?.corridorKm === CORRIDOR_KM;
  if (raw && !usable) {
    console.log(
      raw.corridorKm
        ? `  목록 캐시가 ${raw.corridorKm}km 기준이다 (지금 ${CORRIDOR_KM}km) — 다시 받는다`
        : '  목록 캐시에 회랑 폭이 없다 (옛 형식) — 다시 받는다',
    );
  }
  /** 이미 목록을 받아둔 시도. **시도 단위로 이어받는다.** */
  const listed = new Set<string>(usable ? (raw!.regions ?? []) : []);
  if (usable) for (const [id, it] of Object.entries(raw!.items!)) seen.set(id, it);

  const todo = regions.filter((rg) => !listed.has(rg.regn));
  if (!todo.length) {
    console.log(`  목록 캐시 ${seen.size}건 · 시도 ${listed.size}개 (다시 받으려면 RELIST=1)`);
  } else {
    if (seen.size) console.log(`  목록 캐시 ${seen.size}건 · 남은 시도 ${todo.length}개`);

    /** 회랑 판정 — 실제 노선 선형(`near_routes` RPC). 한 번에 다 던지면 요청이 커서 나눈다. */
    const keepInCorridor = async (rows: Item[]) => {
      const CHUNK = 300;
      for (let i = 0; i < rows.length; i += CHUNK) {
        const slice = rows.slice(i, i + CHUNK);
        const { data, error } = await db.rpc('near_routes', {
          p_points: slice.map((r) => [Number(r.mapy), Number(r.mapx)]),
          p_max_km: CORRIDOR_KM,
        });
        if (error) throw new Error(`회랑 판정 실패: ${error.message}`);
        for (const row of (data ?? []) as { idx: number; distance_km: number }[]) {
          const r = slice[row.idx];
          // ⚠ **국도까지의 거리를 실어둔다.** 상세를 가까운 순으로 받기 위해서다 —
          //   할당량이 며칠에 걸쳐 나뉘니 '먼저 받는 것'이 곧 '먼저 쓸 수 있는 것'이다.
          if (r?.contentid) seen.set(r.contentid, { ...r, _km: String(row.distance_km) });
        }
      }
    };

    /**
     * ⚠ **시도 하나가 끝날 때마다 캐시를 쓴다.**
     *   전에는 전부 받은 뒤 마지막에 한 번만 썼다 — 중간에 한도에 걸리면 그때까지 받은
     *   목록이 통째로 날아간다. 상세 단계에서 실제로 그 사고를 겪었다 (2026-09-03).
     */
    const save = () => {
      const out: Cache = {
        corridorKm: CORRIDOR_KM,
        regions: [...listed],
        items: Object.fromEntries(seen),
      };
      writeFileSync(CACHE, JSON.stringify(out, null, 0), 'utf-8');
    };

    try {
      for (const rg of todo) {
        const rows = await listRegion(rg.name, rg.regn);
        const ok = rows.filter(
          (r) => r.contentid && Number.isFinite(Number(r.mapy)) && Number.isFinite(Number(r.mapx)),
        );
        console.log(`  ${rg.name}(${rg.regn}): ${rows.length}건`);
        // ⚠ **0건이면 멈춘다.** 시도 코드가 바뀌면 그 지역이 통째로 비는데, 경고만 찍고
        //   넘어가면 아무도 안 본다. 광주·전남·세종 3,896건이 그렇게 빠져 있었다 (2026-09-03).
        //   코드는 `ldongCode2` API가 정본을 준다.
        if (!ok.length) {
          throw new Error(
            `${rg.name}(${rg.regn}) 0건 — 시도 코드가 바뀌었을 수 있다. ` +
              `ldongCode2 API로 정본 코드를 확인할 것`,
          );
        }
        await keepInCorridor(ok);
        listed.add(rg.regn);
        save();
      }
    } catch (e) {
      save();
      console.log(`\n  목록 중단: ${e instanceof Error ? e.message.slice(0, 120) : e}`);
      console.log(`  시도 ${listed.size}/${regions.length}개까지 남겼다. 같은 명령으로 이어받는다.`);
    }
    console.log(`  회랑 ${CORRIDOR_KM}km 안 ${seen.size}건 (목록 캐시에 남겼다)`);
  }

  console.log(`\n합계 ${seen.size}건. 상세를 채웁니다…`);

  // 2) 상세를 채우고 점수를 매긴다.
  //    스팟 하나에 3콜이라 순차로 돌리면 1,000건에 15분이 넘는다. 묶어서 동시에 친다.
  const spots: Record<string, unknown>[] = [];
  /** 적재를 마친 것들. `spots`는 flush 때 비워지므로 보고는 이쪽을 본다. */
  const kept: Record<string, unknown>[] = [];
  const events: { contentid: string; title: string; start: string; end: string }[] = [];
  let done = 0;

  // ⚠ TourAPI는 **일일 요청 제한**이 있다. 스팟 하나에 2~3콜이라 1,000건이면 금방 닿는다.
  //   이미 채운 건 건너뛰어 다음 날 이어받는다. RESET=1이면 전부 다시 받는다.
  const { data: existing } = await db.from('spots').select('tourapi_contentid').gt('trust_score', 0);
  const doneIds = new Set((existing ?? []).map((r) => r.tourapi_contentid as string));
  const reset = process.env.RESET === '1';

  /**
   * 대표사진이 없으면 **게이트(60)를 넘을 수 없다.**
   *
   * 사진 35점이 배점의 최대 항목이다. 없으면 전화15 + 영업시간20 + 주소10 = **45가 천장**이다.
   * (추가사진 10점은 base 50~59일 때만 조회하니 안 붙고, 개요 10점은 게이트를 통과한
   *  뒤 `fetch:overview` 단계에서 채운다.)
   * 60을 못 넘으면 레이더에 영영 안 뜬다 — 상세 콜을 쓸 이유가 없다.
   * 강원 표본에서 **26%(1,007건)** 가 여기 걸린다 (2026-09-03 실측).
   *
   * ⚠ 게이트를 안 거는 화면이 생기면 이들도 필요해진다. 그때는 `KEEP_NO_PHOTO=1`.
   */
  const keepNoPhoto = process.env.KEEP_NO_PHOTO === '1';
  const hasPhoto = (i: Item) => Boolean((i.firstimage ?? '').trim());

  /**
   * 목록 데이터만으로 매긴 점수. 사진35 + 전화15 + 번지주소10.
   * **이미 60이면 상세를 받을 이유가 없다** — 게이트를 이미 넘었다.
   * 축제공연행사는 목록에 전화가 들어와서 89%가 여기 걸린다 (2026-09-03 실측).
   */
  const listScore = (i: Item) =>
    (hasPhoto(i) ? 35 : 0) +
    ((i.tel ?? '').trim() ? 15 : 0) +
    (/\d/.test((i.addr1 ?? '').trim()) ? 10 : 0);

  const dropped = [...seen].filter(([, i]) =>
    (DROPPED_TYPES as readonly string[]).includes(i.contenttypeid),
  ).length;
  const mapped = [...seen].filter(([, i]) => TYPE_MAP[i.contenttypeid]);
  const noPhoto = keepNoPhoto ? 0 : mapped.filter(([, i]) => !hasPhoto(i)).length;
  const enough = mapped.filter(([, i]) => hasPhoto(i) && listScore(i) >= 60).length;
  const targets = mapped
    .filter(
      ([id, i]) =>
        (keepNoPhoto || hasPhoto(i)) && listScore(i) < 60 && (reset || !doneIds.has(id)),
    )
    // ⚠ **국도에 가까운 것부터.** 하루 1,000건씩 며칠에 걸쳐 받으므로,
    //   중간에 멈춰도 길 위에서 실제로 만날 곳이 먼저 채워져 있어야 한다.
    //   거리를 모르는 옛 캐시는 뒤로 보낸다 (Infinity).
    .sort(([, a], [, b]) => (Number(a._km ?? Infinity) - Number(b._km ?? Infinity)) || 0);
  if (dropped) console.log(`  안 받는 유형 ${dropped}건 (쇼핑·문화시설 — TYPE_MAP 주석 참조)`);
  if (noPhoto) {
    console.log(`  사진 없는 ${noPhoto}건은 건너뛴다 — 게이트(60)를 넘을 수 없다 (KEEP_NO_PHOTO=1로 포함)`);
  }
  if (enough) console.log(`  목록만으로 60점인 ${enough}건은 상세를 안 받는다`);
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
    // 사진 저작권 유형 (공공누리). Type3 = 변경금지 — 사진을 합성·크롭하면 안 된다.
    // ⚠ **수집할 때 같이 받아야 한다.** 나중에 넣으려면 전국을 다시 받아야 한다.
    //   지금 앱은 원본 URL을 그대로 띄우니 당장 쓰이지는 않는다 (2026-09-03).
    const rights = ['Type1', 'Type3'].includes((item.cpyrhtDivCd ?? '').trim())
      ? (item.cpyrhtDivCd as string).trim()
      : null;

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
      image_rights: rights,
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

  /**
   * 받은 만큼 **그때그때 적재한다.**
   *
   * ⚠ 전에는 전부 받은 뒤 마지막에 한 번만 upsert했다. 일일 한도에 걸려 예외가 나면
   *   **그날 받은 게 통째로 날아갔다** — 2026-09-03 강원 시험에서 1,000건을 받고
   *   0건이 저장됐다. 하루치 할당량을 그냥 태운 셈이다.
   *   '이미 채운 건 건너뛴다'는 재개 전략도 저장이 돼야 성립한다.
   */
  let saved = 0;
  async function flush() {
    if (!spots.length) return;
    const batch = spots.splice(0, spots.length);
    const { error } = await db
      .from('spots')
      .upsert(batch, { onConflict: 'tourapi_contentid' })
      .select('id');
    if (error) throw new Error(`spots 적재 실패: ${error.message}`);
    saved += batch.length;
    kept.push(...batch);
  }

  try {
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
      // 200건마다 내려놓는다. 한도에 걸려도 여기까지는 남는다.
      if (spots.length >= 200) await flush();
      if (i + LANES < targets.length) await new Promise((r) => setTimeout(r, GAP_MS));
    }
  } catch (e) {
    // ⚠ **터지기 전에 받아둔 것부터 저장한다.** 그래야 내일 이어받을 수 있다.
    await flush();
    console.log(`\n  중단: ${e instanceof Error ? e.message.slice(0, 120) : e}`);
    console.log(`  여기까지 ${saved}건 저장했다. 한도가 풀리면 같은 명령으로 이어받는다.`);
  }
  await flush();
  if (failures) console.log(`  ⚠ 응답을 못 받은 요청 ${failures}건 — 그만큼 항목이 비어 있을 수 있다`);

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
  const pass = kept.filter((s) => (s.trust_score as number) >= 60).length;
  const byType = kept.reduce<Record<string, number>>((m, s) => {
    m[s.type as string] = (m[s.type as string] ?? 0) + 1;
    return m;
  }, {});
  console.log(`\n✓ spots ${kept.length}건 적재`);
  console.log(`  유형: ${Object.entries(byType).map(([k, v]) => `${k} ${v}`).join(' · ')}`);
  console.log(
    `  신뢰도 게이트(60) 통과 ${pass}건` +
      (kept.length ? ` (${Math.round((pass / kept.length) * 100)}%)` : ''),
  );
  console.log(
    `  전화 보유 ${kept.filter((s) => s.tel).length}건 · 사진 보유 ${kept.filter((s) => s.image_url).length}건`,
  );
  const rightsKnown = kept.filter((s) => s.image_rights).length;
  console.log(`  사진 저작권 유형 확인 ${rightsKnown}건 (Type3 = 변경금지)`);
  console.log('\n· 개요는 아직 비어 있다 — `npm run fetch:overview`로 게이트 통과분만 채운다.');
  console.log('· exit_frac·detour_min은 별도 단계에서 계산한다.');
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

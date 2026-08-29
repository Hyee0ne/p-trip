/**
 * M1 데이터 실측 스파이크 — 파이프라인 착수 전 필수 (ROADMAP M1 첫 항목).
 *
 * 확인할 것:
 *  1. 데이터랩이 시점 2개를 주는가 → 못 주면 CO-01 "조용히 뜨는 길" 불가
 *  2. 연관관광지 API가 기준연월 파라미터를 받는가 → 못 받으면 "차량 유입 급증" 불가
 *  3. 데이터랩 입도(시군구) ↔ 코스/스팟 매칭 방법
 *  4. TourAPI 쿼터와 실제 응답 스키마 (문서와 다른 필드 주의)
 *  5. 출몰시각이 월출·월몰·박명까지 주는가 → 별 보기 좋은 밤 계산의 전제
 *  6. 천문현상에 유성우가 들어오는가, 관측 조건 문장이 실려 오는가
 *
 * ⚠ 결과에 따라 fetch-*.ts의 구현 방식이 갈린다. 결과를 먼저 공유할 것.
 *
 * 실행: cd pipeline && npm run probe
 * 결과: 콘솔 요약 + probe-report.json (원문 일부 포함, .gitignore 대상)
 */

import { writeFileSync } from 'node:fs';
import { config } from 'dotenv';

config({ path: '../.env' });

/** 데모 기준 좌표 — 동해시, 7번 국도 위 (CLAUDE.md 데모 기준 데이터). */
const DEMO = { lat: 37.5245, lng: 129.1143, area: '동해' };

/** 오늘. 출몰시각·천문현상 조회 기준. */
const TODAY = new Date();
const yyyymmdd = (d: Date) =>
  `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;

type Probe = {
  name: string;
  question: string;
  ok: boolean;
  url?: string;
  status?: number;
  note: string;
  fields?: string[];
  sample?: unknown;
};

const report: Probe[] = [];

/** 키가 로그·리포트에 남지 않게 지운다. */
function mask(url: string): string {
  return url.replace(/(serviceKey|ServiceKey)=[^&]*/g, '$1=***');
}

/**
 * 후보 URL을 순서대로 때려보고 처음 성공한 것을 쓴다.
 * 엔드포인트가 버전업으로 바뀌는 일이 잦아서, 추측 하나에 걸지 않는다.
 */
async function tryFetch(
  candidates: string[],
): Promise<{ url: string; status: number; body: string } | null> {
  for (const url of candidates) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(15_000) });
      const body = await res.text();
      // data.go.kr은 실패해도 200에 에러 XML을 실어 보낸다. 본문까지 봐야 한다.
      const failed =
        !res.ok ||
        /SERVICE[_ ]?ERROR|SERVICE_KEY_IS_NOT_REGISTERED|NO_OPENAPI_SERVICE_ERROR|APPLICATION_ERROR|<errMsg>/i.test(
          body,
        );
      if (!failed) return { url, status: res.status, body };
      // 마지막 후보면 실패 본문이라도 돌려줘서 원인을 볼 수 있게 한다.
      if (url === candidates[candidates.length - 1]) {
        return { url, status: res.status, body };
      }
    } catch (e) {
      if (url === candidates[candidates.length - 1]) {
        return { url, status: 0, body: String(e) };
      }
    }
  }
  return null;
}

/** XML/JSON 어느 쪽이 와도 필드 이름을 뽑는다. 스키마 확인이 목적이다. */
function fieldsOf(body: string): string[] {
  const trimmed = body.trim();
  if (trimmed.startsWith('{')) {
    try {
      const walk = (o: unknown, depth = 0): string[] => {
        if (depth > 6 || o === null || typeof o !== 'object') return [];
        if (Array.isArray(o)) return o.length ? walk(o[0], depth + 1) : [];
        return Object.entries(o).flatMap(([k, v]) =>
          v !== null && typeof v === 'object' ? walk(v, depth + 1) : [k],
        );
      };
      return [...new Set(walk(JSON.parse(trimmed)))];
    } catch {
      /* XML 경로로 떨어진다 */
    }
  }
  const tags = trimmed.match(/<([a-zA-Z][\w:.-]*)>/g) ?? [];
  return [...new Set(tags.map((t) => t.slice(1, -1)))];
}

/** XML 태그 하나의 값들을 전부 뽑는다. */
function valuesOf(body: string, tag: string): string[] {
  const re = new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`, 'g');
  return [...body.matchAll(re)].map((m) =>
    m[1].replace(/<!\[CDATA\[|\]\]>/g, '').trim(),
  );
}

function add(p: Probe) {
  report.push(p);
  const mark = p.ok ? '✓' : '✗';
  console.log(`\n${mark} ${p.name}`);
  console.log(`  질문: ${p.question}`);
  console.log(`  결과: ${p.note}`);
  if (p.url) console.log(`  URL : ${mask(p.url)} (${p.status})`);
  if (p.fields?.length) console.log(`  필드: ${p.fields.join(', ')}`);
}

// ──────────────────────────────────────────────────────────
// 1. TourAPI — 위치기반 관광정보
// ──────────────────────────────────────────────────────────
async function probeTourApi(key: string) {
  const common = `serviceKey=${key}&MobileOS=ETC&MobileApp=PTrip&_type=json&numOfRows=10&pageNo=1`;
  const geo = `mapX=${DEMO.lng}&mapY=${DEMO.lat}&radius=5000`;
  const r = await tryFetch([
    `https://apis.data.go.kr/B551011/KorService2/locationBasedList2?${common}&${geo}`,
    `https://apis.data.go.kr/B551011/KorService1/locationBasedList1?${common}&${geo}`,
  ]);
  if (!r) return add({ name: 'TourAPI 위치기반관광정보', question: '데모 구간 반경 5km에 스팟이 몇 개인가', ok: false, note: '호출 자체가 실패했다' });

  let count = '?';
  try {
    const j = JSON.parse(r.body);
    count = String(j?.response?.body?.totalCount ?? '?');
  } catch {
    count = valuesOf(r.body, 'totalCount')[0] ?? '?';
  }
  const ok = count !== '?' && count !== '0';
  add({
    name: 'TourAPI 위치기반관광정보',
    question: '데모 구간(동해시) 반경 5km에 스팟이 몇 개이고, 응답 필드가 문서와 같은가',
    ok,
    url: r.url,
    status: r.status,
    note: ok
      ? `반경 5km totalCount = ${count}. 사용할 엔드포인트: ${r.url.includes('KorService2') ? 'KorService2' : 'KorService1'}`
      : `totalCount를 못 읽었다. 응답 앞부분: ${r.body.slice(0, 220)}`,
    fields: fieldsOf(r.body).slice(0, 40),
    sample: r.body.slice(0, 1200),
  });
  return r;
}

// ──────────────────────────────────────────────────────────
// 2. 연관 관광지 — 기준연월(baseYm)을 받는가
//    받으면 "요즘 차들이 몰래 가는 곳"(유입 급증)을 시점 비교로 만들 수 있다.
// ──────────────────────────────────────────────────────────
async function probeRelated(key: string) {
  const prev = new Date(TODAY.getFullYear(), TODAY.getMonth() - 2, 1);
  const baseYm = `${prev.getFullYear()}${String(prev.getMonth() + 1).padStart(2, '0')}`;
  const common = `serviceKey=${key}&MobileOS=ETC&MobileApp=PTrip&_type=json&numOfRows=5&pageNo=1`;
  const r = await tryFetch([
    `https://apis.data.go.kr/B551011/TarRlteTarService1/areaBasedList1?${common}&baseYm=${baseYm}&areaCd=51&signguCd=51150`,
    `https://apis.data.go.kr/B551011/TarRlteTarService/areaBasedList?${common}&baseYm=${baseYm}&areaCd=51&signguCd=51150`,
  ]);
  if (!r) return add({ name: '연관 관광지', question: '기준연월 파라미터를 받는가', ok: false, note: '호출 실패' });

  const err = valuesOf(r.body, 'errMsg')[0] ?? valuesOf(r.body, 'returnAuthMsg')[0];
  const ok = !err && /rlteTatsNm|rlteBsicAdres|rlteCtgry/i.test(r.body);
  add({
    name: '연관 관광지 (기준연월)',
    question: `baseYm=${baseYm}을 받아 그 달 기준 연관 관광지를 주는가 → "요즘 차들이 몰래 가는 곳" 가능 여부`,
    ok,
    url: r.url,
    status: r.status,
    note: ok
      ? `받는다. 두 달을 각각 조회해 비교하면 유입 급증 산출 가능`
      : `안 되거나 파라미터가 다르다. ${err ?? r.body.slice(0, 220)}`,
    fields: fieldsOf(r.body).slice(0, 30),
    sample: r.body.slice(0, 1000),
  });
}

// ──────────────────────────────────────────────────────────
// 3. 출몰시각 — 월출·월몰·박명까지 오는가
//    별 보기 좋은 밤 = 천문박명 이후 + 달 방해 낮음. 그 전제가 여기다.
// ──────────────────────────────────────────────────────────
async function probeRiseSet(key: string) {
  const locdate = yyyymmdd(TODAY);
  const base = 'https://apis.data.go.kr/B090041/openapi/service/RiseSetInfoService';
  const r = await tryFetch([
    `${base}/getAreaRiseSetInfo?serviceKey=${key}&locdate=${locdate}&location=${encodeURIComponent(DEMO.area)}`,
    `${base}/getLCRiseSetInfo?serviceKey=${key}&locdate=${locdate}&longitude=${DEMO.lng}&latitude=${DEMO.lat}&dnYn=Y`,
  ]);
  if (!r) return add({ name: '출몰시각', question: '월출·월몰·박명이 오는가', ok: false, note: '호출 실패' });

  const f = fieldsOf(r.body);
  const has = (t: string) => f.some((x) => x.toLowerCase() === t.toLowerCase());
  const moon = has('moonrise') && has('moonset');
  const twilight = f.some((x) => /civil|naut|astm/i.test(x));
  add({
    name: '출몰시각 (일출·일몰·월출·월몰·박명)',
    question: '일몰뿐 아니라 월출·월몰·천문박명까지 오는가 → 별 보기 좋은 밤 계산 가능 여부',
    ok: has('sunset'),
    url: r.url,
    status: r.status,
    note: [
      has('sunrise') && has('sunset') ? '일출·일몰 ○' : '일출·일몰 ✗',
      moon ? '월출·월몰 ○' : '월출·월몰 ✗',
      twilight ? '박명 ○' : '박명 ✗',
      moon && twilight ? '→ 달 방해 계산 가능' : '→ 필드가 모자라면 계산식을 줄여야 한다',
    ].join(' · '),
    fields: f,
    sample: r.body.slice(0, 1200),
  });
}

// ──────────────────────────────────────────────────────────
// 4. 천문현상 — 유성우가 들어오는가, 관측 조건 문장이 실려 오는가
// ──────────────────────────────────────────────────────────
async function probeAstro(key: string) {
  const base =
    'https://apis.data.go.kr/B090041/openapi/service/AstroEventInfoService/getAstroEventInfo';
  const year = TODAY.getFullYear();
  // 8월 페르세우스자리, 12월 쌍둥이자리 — 유성우가 실제로 실리는지 보기 좋은 달.
  const months = ['08', '12', String(TODAY.getMonth() + 1).padStart(2, '0')];
  const titles: string[] = [];
  const events: string[] = [];
  let last: Awaited<ReturnType<typeof tryFetch>> = null;

  for (const m of [...new Set(months)]) {
    const r = await tryFetch([
      `${base}?serviceKey=${key}&solYear=${year}&solMonth=${m}&numOfRows=50`,
    ]);
    if (!r) continue;
    last = r;
    titles.push(...valuesOf(r.body, 'astroTitle'));
    events.push(...valuesOf(r.body, 'astroEvent'));
  }

  const meteor = titles.filter((t) => /유성우/.test(t));
  const eclipse = titles.filter((t) => /월식|일식/.test(t));
  // 천문연 보도자료는 달빛 방해를 문장으로 적는다. 그게 API에도 실리는지가 핵심.
  const condition = events.filter((e) => /달빛|관측 조건|보름달|월령/.test(e));

  add({
    name: '천문현상',
    question: '유성우·월식이 들어오는가, astroEvent에 관측 조건(달빛) 문장이 실리는가',
    ok: titles.length > 0,
    url: last?.url,
    status: last?.status,
    note:
      titles.length === 0
        ? `현상이 하나도 안 왔다. 응답 앞부분: ${last?.body.slice(0, 220) ?? '(없음)'}`
        : [
            `총 ${titles.length}건`,
            `유성우 ${meteor.length}건${meteor.length ? ` (${meteor.slice(0, 3).join(', ')})` : ''}`,
            `월식·일식 ${eclipse.length}건`,
            condition.length
              ? `관측 조건 문장 ○ (${condition.length}건) → 그대로 인용 가능`
              : `관측 조건 문장 ✗ → 달 방해는 출몰시각으로 우리가 계산해야 한다`,
          ].join(' · '),
    fields: last ? fieldsOf(last.body).slice(0, 20) : undefined,
    sample: { titles: titles.slice(0, 12), events: events.slice(0, 4) },
  });
}

// ──────────────────────────────────────────────────────────
// 5. 전통시장 표준데이터 — 장날 끝자리가 어떤 표기로 오는가
// ──────────────────────────────────────────────────────────
async function probeMarkets(key: string) {
  const r = await tryFetch([
    `https://api.odcloud.kr/api/15052837/v1/uddi:a9b3e0d0-1c04-4b2c-9a0f-b96f6f18e56f?serviceKey=${key}&page=1&perPage=5`,
    `https://apis.data.go.kr/1741000/StandardMarket/getStandardMarketList?serviceKey=${key}&pageNo=1&numOfRows=5&type=json`,
  ]);
  const f = r ? fieldsOf(r.body) : [];
  const dayField = f.find((x) => /개설주기|장날|주기/.test(x));
  add({
    name: '전통시장 표준데이터',
    question: '장날 끝자리가 어떤 표기로 오는가 (예: "3,8" / "3·8일" / "매월 3일,8일")',
    ok: Boolean(dayField),
    url: r?.url,
    status: r?.status,
    note: dayField
      ? `장날 필드 발견: ${dayField}. 표기 정규화 규칙을 여기서 정한다`
      : `엔드포인트를 못 찾았다. 표준데이터는 파일(CSV)로도 받을 수 있으니 그쪽이 빠를 수 있다. 응답: ${r?.body.slice(0, 200) ?? '(없음)'}`,
    fields: f.slice(0, 30),
    sample: r?.body.slice(0, 800),
  });
}

// ──────────────────────────────────────────────────────────
async function main() {
  const tour = process.env.TOURAPI_KEY?.trim();
  const dataGo = process.env.DATA_GO_KR_KEY?.trim();
  const datalab = process.env.DATALAB_KEY?.trim();

  console.log('P의 여행 — API 실측 스파이크');
  console.log(`기준 좌표: ${DEMO.area} ${DEMO.lat}, ${DEMO.lng} (7번 국도)`);
  console.log(
    `키: TOURAPI ${tour ? '○' : '✗'} · DATA_GO_KR ${dataGo ? '○' : '✗'} · DATALAB ${datalab ? '○' : '✗'}`,
  );

  if (tour) {
    await probeTourApi(tour);
    await probeRelated(tour);
  } else {
    console.log('\n⚠ TOURAPI_KEY가 없어 TourAPI 검사를 건너뛴다.');
  }

  if (dataGo) {
    await probeRiseSet(dataGo);
    await probeAstro(dataGo);
    await probeMarkets(dataGo);
  } else {
    console.log('\n⚠ DATA_GO_KR_KEY가 없어 출몰시각·천문현상·전통시장 검사를 건너뛴다.');
  }

  if (!datalab) {
    console.log(
      '\n⚠ DATALAB_KEY가 없다. CO-01 "조용히 뜨는 길"의 두 시점 제공 여부는 아직 미확인이다.',
    );
  }

  writeFileSync('probe-report.json', JSON.stringify(report, null, 2), 'utf8');
  const failed = report.filter((p) => !p.ok);
  console.log(`\n───\n${report.length}건 중 ${report.length - failed.length}건 통과.`);
  if (failed.length) console.log(`확인 필요: ${failed.map((p) => p.name).join(', ')}`);
  console.log('상세: pipeline/probe-report.json');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

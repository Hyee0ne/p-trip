/**
 * 천문연 천문현상 정보 → astro_events.
 *
 * ⚠ **앱에서 읽는 곳이 없다** (§3.8 삭제, 2026-09-07). 테이블만 채워 둔다.
 *
 * ⚠ **좌표가 없다.** 전국 공통 값이라 "여기서만"이 아니라 "오늘만"으로만 쓴다.
 *   스팟으로 만들어 레이더에 띄우면 위치를 지어내는 것이다 (원칙 2).
 *
 * ⚠ 응답이 두 종류로 섞여 온다 (2026-08-29 실측, 2026년 198건):
 *   - astroTitle 있음 (12건)  = 사람에게 보여줄 '사건' — 유성우 3, 개기월식 1, 계절 별자리 4 …
 *   - astroTitle 없음 (186건) = 삭·망·근지점 같은 **월상 달력**. 화면에 "망"이라고 띄우면 안 된다.
 *   is_event로 갈라 담는다. 후자는 월령 계산 입력값이다.
 *
 * 실행: cd pipeline && npm run fetch:astro
 *       YEARS=2026,2027 npm run fetch:astro
 */

import { supabase } from './lib/supabase.js';

const KEY = process.env.DATA_GO_KR_KEY?.trim();
const URL =
  'https://apis.data.go.kr/B090041/openapi/service/AstroEventInfoService/getAstroEventInfo';

const YEARS = (process.env.YEARS ?? `${new Date().getFullYear()},${new Date().getFullYear() + 1}`)
  .split(',')
  .map((y) => y.trim())
  .filter(Boolean);

function items(xml: string): { title: string; time: string; event: string; date: string }[] {
  const blocks = xml.match(/<item>[\s\S]*?<\/item>/g) ?? [];
  const get = (b: string, t: string) =>
    (b.match(new RegExp(`<${t}>([\\s\\S]*?)</${t}>`))?.[1] ?? '')
      .replace(/<!\[CDATA\[|\]\]>/g, '')
      .trim();
  return blocks.map((b) => ({
    date: get(b, 'locdate'),
    title: get(b, 'astroTitle'),
    time: get(b, 'astroTime'),
    event: get(b, 'astroEvent'),
  }));
}

/**
 * locdate를 날짜로 바꾼다.
 *
 * ⚠ 두 형식이 섞여 온다 (2026-08-29 실측):
 *   - 월상 달력 항목: '20260813' (YYYYMMDD)
 *   - **제목 있는 사건: '202608  ' (YYYYMM)** — 일자가 없다!
 *     처음에 8자리만 받게 해뒀다가 유성우·월식 12건을 통째로 버렸다.
 *     일자는 제목에 있다 ("8월 13일 페르세우스자리 유성우") — 거기서 읽는다.
 *     기간 표기('12월 14~15일')는 첫날을 쓴다. 제목에 일자가 없으면(계절 별자리 등) 1일.
 */
function toDate(raw: string, title: string): string | null {
  const v = raw.trim();
  if (/^\d{8}$/.test(v)) return `${v.slice(0, 4)}-${v.slice(4, 6)}-${v.slice(6, 8)}`;
  if (!/^\d{6}$/.test(v)) return null;
  const year = v.slice(0, 4);
  const month = v.slice(4, 6);
  const m = title.match(/(\d{1,2})월\s*(\d{1,2})/);
  const day = m && m[1] === String(Number(month)) ? m[2] : '1';
  return `${year}-${month}-${String(day).padStart(2, '0')}`;
}

async function main() {
  if (!KEY) throw new Error('DATA_GO_KR_KEY가 비어 있습니다.');
  const db = supabase();
  const rows: Record<string, unknown>[] = [];

  for (const year of YEARS) {
    let n = 0;
    for (let m = 1; m <= 12; m++) {
      const url = `${URL}?serviceKey=${KEY}&solYear=${year}&solMonth=${String(m).padStart(2, '0')}&numOfRows=100`;
      const res = await fetch(url, { signal: AbortSignal.timeout(15_000) });
      const xml = await res.text();
      if (/LIMITED_NUMBER/i.test(xml)) throw new Error('일일 요청 제한 초과');
      for (const it of items(xml)) {
        const date = toDate(it.date, it.title);
        if (!date) continue;
        rows.push({
          locdate: date,
          title: it.title,
          // 'HHMM' 또는 빈 값. 시각이 없는 항목도 많다 (계절 별자리 등).
          event_time: /^\d{4}$/.test(it.time) ? `${it.time.slice(0, 2)}:${it.time.slice(2)}` : null,
          description: it.event,
          // 제목이 붙어 있는 것만 사용자에게 보인다.
          is_event: it.title.length > 0,
        });
        n++;
      }
    }
    console.log(`  ${year}년 ${n}건`);
  }

  const { error } = await db
    .from('astro_events')
    .upsert(rows, { onConflict: 'locdate,title,description' });
  if (error) throw new Error(`astro_events 적재 실패: ${error.message}`);

  const events = rows.filter((r) => r.is_event);
  console.log(`\n✓ ${rows.length}건 적재 — 노출용 ${events.length}건 · 월상 달력 ${rows.length - events.length}건`);
  console.log('\n노출용 목록:');
  for (const e of events) {
    console.log(`  ${e.locdate}  ${e.event_time ?? '  -  '}  ${e.title}`);
  }
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});

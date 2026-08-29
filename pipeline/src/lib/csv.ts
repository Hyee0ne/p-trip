import { readFileSync } from 'node:fs';

/**
 * 따옴표를 아는 최소 CSV 파서.
 * ⚠ split(',')로 자르면 주소 안의 콤마에서 열이 밀린다.
 *   실제로 그 착시 때문에 멀쩡한 장날 데이터를 '오염'으로 오인한 적이 있다.
 */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;

  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"') {
        if (text[i + 1] === '"') { cell += '"'; i++; }
        else quoted = false;
      } else cell += c;
      continue;
    }
    if (c === '"') quoted = true;
    else if (c === ',') { row.push(cell.trim()); cell = ''; }
    else if (c === '\n') { row.push(cell.trim()); rows.push(row); row = []; cell = ''; }
    else if (c !== '\r') cell += c;
  }
  if (cell || row.length) { row.push(cell.trim()); rows.push(row); }
  return rows.filter((r) => r.some((x) => x));
}

/** data.go.kr 파일은 EUC-KR로 오는 일이 많다. 깨지면 UTF-8로 다시 읽는다. */
export function readCsv(path: string): { header: string[]; rows: string[][] } {
  const raw = readFileSync(path);
  let text = new TextDecoder('euc-kr').decode(raw);
  if (text.includes('�')) text = new TextDecoder('utf-8').decode(raw);
  const table = parseCsv(text);
  return { header: table[0] ?? [], rows: table.slice(1) };
}

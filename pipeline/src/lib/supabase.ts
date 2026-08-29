import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { config } from 'dotenv';

// .env는 리포 루트에 있다. 스크립트는 pipeline/에서 돌지만 루트에서 부를 수도 있어
// 양쪽을 다 본다. 먼저 읽힌 값이 이긴다.
config({ path: '../.env' });
config({ path: '.env' });

/**
 * Supabase 클라이언트 — **프로젝트 오조준 방지 가드 포함**.
 *
 * 이 저장소를 만지는 사람은 `brrrp` 등 다른 Supabase 프로젝트를 함께 쓴다.
 * `.env`를 잘못 두면 남의 프로젝트에 적재·마이그레이션이 들어간다.
 * 그래서 URL에서 뽑은 project ref를 `SUPABASE_EXPECTED_REF`와 대조하고,
 * 다르면 **연결 자체를 거부한다**. (supabase/README.md 격리 규칙 4)
 */

/** `https://abcdefgh.supabase.co` → `abcdefgh` */
export function projectRefFromUrl(url: string): string | null {
  const m = url.match(/^https:\/\/([a-z0-9]+)\.supabase\.(co|in)/i);
  return m ? m[1].toLowerCase() : null;
}

export function assertCorrectProject(): { url: string; ref: string } {
  const url = process.env.SUPABASE_URL?.trim();
  const expected = process.env.SUPABASE_EXPECTED_REF?.trim().toLowerCase();

  if (!url) {
    throw new Error('SUPABASE_URL이 비어 있습니다. .env를 확인하세요 (.env.example 참조).');
  }
  if (!expected) {
    throw new Error(
      'SUPABASE_EXPECTED_REF가 비어 있습니다.\n' +
        '  오조준 방지 가드라 생략할 수 없습니다. .env에 P의 여행 프로젝트 ref를 넣으세요.\n' +
        '  ref 확인: supabase projects list',
    );
  }

  const actual = projectRefFromUrl(url);
  if (!actual) {
    throw new Error(`SUPABASE_URL 형식이 이상합니다: ${url}`);
  }
  if (actual !== expected) {
    throw new Error(
      '\n⛔ 다른 Supabase 프로젝트를 가리키고 있습니다. 실행을 중단합니다.\n' +
        `     SUPABASE_URL       → ${actual}\n` +
        `     SUPABASE_EXPECTED_REF → ${expected}\n\n` +
        '  P의 여행이 아닌 프로젝트(brrrp 등)에 적재될 뻔했습니다.\n' +
        '  .env의 SUPABASE_URL을 고치거나, 의도한 게 맞다면 EXPECTED_REF를 바꾸세요.\n',
    );
  }
  return { url, ref: actual };
}

let _client: SupabaseClient | null = null;

/** 가드를 통과한 service_role 클라이언트. 파이프라인 전용 — 앱에서 쓰지 않는다. */
export function supabase(): SupabaseClient {
  if (_client) return _client;
  const { url } = assertCorrectProject();
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!key) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY가 비어 있습니다.');
  }
  _client = createClient(url, key, { auth: { persistSession: false } });
  return _client;
}

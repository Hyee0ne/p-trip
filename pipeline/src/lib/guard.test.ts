/**
 * 가드 검증 — 실행: `npx tsx src/lib/guard.test.ts`
 * 프로젝트 오조준이 실제로 차단되는지 확인한다.
 */
import { projectRefFromUrl, assertCorrectProject } from './supabase.js';

let failed = 0;
function check(name: string, fn: () => void) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
  } catch (e) {
    failed++;
    console.log(`  ✗ ${name}\n    ${(e as Error).message.split('\n')[0]}`);
  }
}
function expectThrow(name: string, fn: () => void) {
  try {
    fn();
    failed++;
    console.log(`  ✗ ${name} — 차단됐어야 하는데 통과함`);
  } catch {
    console.log(`  ✓ ${name}`);
  }
}

console.log('projectRefFromUrl');
check('정상 URL에서 ref 추출', () => {
  const r = projectRefFromUrl('https://abcdefghijkl.supabase.co');
  if (r !== 'abcdefghijkl') throw new Error(`got ${r}`);
});
check('형식이 아니면 null', () => {
  if (projectRefFromUrl('http://localhost:55321') !== null) throw new Error('null이어야 함');
});

console.log('assertCorrectProject');
expectThrow('ref 불일치 → 차단', () => {
  process.env.SUPABASE_URL = 'https://brrrpxxxxxxx.supabase.co';
  process.env.SUPABASE_EXPECTED_REF = 'ptripyyyyyyy';
  assertCorrectProject();
});
expectThrow('EXPECTED_REF 없음 → 차단', () => {
  process.env.SUPABASE_URL = 'https://ptripyyyyyyy.supabase.co';
  delete process.env.SUPABASE_EXPECTED_REF;
  assertCorrectProject();
});
check('일치하면 통과', () => {
  process.env.SUPABASE_URL = 'https://ptripyyyyyyy.supabase.co';
  process.env.SUPABASE_EXPECTED_REF = 'ptripyyyyyyy';
  assertCorrectProject();
});

console.log(failed === 0 ? '\n가드 정상 동작' : `\n${failed}건 실패`);
process.exit(failed === 0 ? 0 : 1);

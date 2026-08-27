# supabase/

마이그레이션과 Edge Function이 여기 들어간다.

## 준비
```bash
brew install supabase/tap/supabase   # CLI 미설치 상태
supabase login
supabase link --project-ref <ref>
supabase db push
```

## 규칙
- 스키마 변경은 **반드시 마이그레이션 파일로**. 대시보드에서 직접 고치지 않는다 (CLAUDE.md).
- PostGIS extension 활성화 필요 (공간 쿼리).
- Edge Function `compare_routes`는 TECH_SPEC §3.7 전용 —
  카카오모빌리티 길찾기 REST 키는 여기에만 존재한다. 앱 번들에 넣지 않는다.

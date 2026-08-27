# supabase/

P의 여행 전용. **`brrrp` 프로젝트와 절대 섞지 않는다.**

## ⚠ 격리 규칙 (2026-08-27)

이 저장소는 `brrrp`와 다른 Supabase 계정/프로젝트를 쓰는 사람이 함께 만질 수 있다.
아래를 어기면 남의 프로젝트에 마이그레이션이 들어간다.

1. **`supabase link`를 인자 없이 실행하지 않는다.**
   반드시 `supabase link --project-ref <ref>` 로 ref를 명시한다.
   현재 링크 대상은 `supabase link --project-ref` 없이 확인: `supabase projects list`
2. **`project_id = "p-trip"`** — Docker 컨테이너 이름 접두사가 갈린다.
3. **로컬 포트는 55321~55329** (기본 54321 대역에서 옮김).
   brrrp 로컬 인스턴스를 동시에 띄워도 충돌하지 않는다.
4. **파이프라인에 가드가 걸려 있다.** `pipeline/src/lib/supabase.ts`가
   `SUPABASE_URL`의 프로젝트 ref와 `SUPABASE_EXPECTED_REF`를 대조하고,
   다르면 실행을 거부한다. `.env`에 두 값을 다 넣어야 돌아간다.

## 준비

```bash
# 1) P의 여행용 프로젝트를 새로 만들거나 기존 것 중 고른다 (brrrp 아님)
supabase projects list

# 2) ref를 명시해서 링크
supabase link --project-ref <p-trip-project-ref>

# 3) .env 에 두 값을 채운다 (.env.example 참조)
#    SUPABASE_URL=https://<ref>.supabase.co
#    SUPABASE_EXPECTED_REF=<ref>

# 4) 마이그레이션 적용
supabase db push
```

## 로컬 개발

```bash
supabase start     # 55321 대역
supabase stop
```

## 규칙

- 스키마 변경은 **반드시 마이그레이션 파일로**. 대시보드에서 직접 고치지 않는다 (CLAUDE.md).
- PostGIS extension 활성화 필요 (공간 쿼리 — TECH_SPEC §2).
- Edge Function `compare_routes`는 TECH_SPEC §3.7 전용.
  카카오모빌리티 길찾기 REST 키는 **여기에만** 존재한다. 앱 번들에 넣지 않는다.

-- 국도는 하나의 연속선이 아니다. 도심 통과·우회·미개통으로 여러 구간으로 끊겨 있고,
-- 도로중심선 원본도 그렇게 들어온다. LineString 하나로 담으면 대부분을 버리게 된다
-- (77번: 63조각 중 2개만 남아 675km가 396점이 됐다).
alter table public.routes
  alter column geom type extensions.geometry(MultiLineString, 4326)
  using extensions.ST_Multi(geom);

comment on column public.routes.geom is
  '전국 노선 선형(MultiLineString). ⚠ ST_LineLocatePoint는 LineString만 받는다 —
   exit_frac은 노선 전체가 아니라 코스(courses.geom)를 기준으로 계산한다.';

-- PostGIS. 발견 쿼리(§3.1)가 반경·최근접점·노선상 위치비를 전부 여기에 기댄다.
-- Supabase 관례대로 extensions 스키마에 둔다.
create extension if not exists postgis with schema extensions;

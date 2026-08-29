/**
 * 7번 국도 해안 구간의 대략 선형. 데모 구간을 걸러내는 데 쓴다.
 * ⚠ 손으로 찍은 근사선이다. routes.geom(실제 선형)이 들어왔으니
 *   나중에 PostGIS ST_Distance로 바꾸는 게 맞다.
 */
export const CORRIDOR: [number, number][] = [
  [129.1650, 37.4500], // 삼척
  [129.1143, 37.5245], // 동해
  [129.1150, 37.5520], // 묵호
  [129.0530, 37.6060], // 망상
  [129.0300, 37.6600], // 옥계
  [129.0340, 37.6900], // 정동진
  [128.8960, 37.7550], // 강릉
];

/** 점과 회랑 사이 거리(km). 위도 37도 부근이라 평면 근사로 충분하다. */
export function distToCorridorKm(lat: number, lng: number): number {
  const KX = 88.0; // 경도 1도 ≈ 88km (위도 37도)
  const KY = 111.0;
  let best = Infinity;
  for (let i = 0; i < CORRIDOR.length - 1; i++) {
    const [x1, y1] = CORRIDOR[i];
    const [x2, y2] = CORRIDOR[i + 1];
    const ax = (lng - x1) * KX, ay = (lat - y1) * KY;
    const bx = (x2 - x1) * KX, by = (y2 - y1) * KY;
    const len2 = bx * bx + by * by;
    const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, (ax * bx + ay * by) / len2));
    best = Math.min(best, Math.hypot(ax - bx * t, ay - by * t));
  }
  return best;
}

/** 두 좌표 사이 거리(m). */
export function distMeters(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const R = 6371000;
  const p1 = (aLat * Math.PI) / 180, p2 = (bLat * Math.PI) / 180;
  const dp = ((bLat - aLat) * Math.PI) / 180, dl = ((bLng - aLng) * Math.PI) / 180;
  const h = Math.sin(dp / 2) ** 2 + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

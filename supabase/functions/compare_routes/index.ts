// TECH_SPEC §3.7 — 고속도로 ↔ 국도 소요시간 비교. **거점 확정 직후 1회.**
//
// ⚠ 이건 길안내가 아니다 (CLAUDE.md 원칙 1의 유일한 예외).
//    "빠른 길 대신 재밌는 길로 갈 이유"를 대는 **설득 근거**일 뿐이다.
//
// 구조적 방어 — 이 파일이 그 방어선이다:
//  - 길찾기 키는 **여기에만** 있다. 앱 번들에 절대 넣지 않는다
//  - 분(minute) 두 개만 돌려준다. **도착 시각·ETA로 환산할 수 있는 값을 주지 않는다**
//  - 경로 좌표(polyline)를 돌려주지 않는다. 받으면 그려보고 싶어진다
//  - 호출은 거점 확정 직후 1회. 이동 중 재조회는 앱에서 막는다

const KAKAO = "https://apis-navi.kakaomobility.com/v1/directions";

/// 한 번 물어본다. 실패하면 null — 지어내지 않는다.
async function ask(
  key: string,
  origin: string,
  destination: string,
  avoid?: string,
): Promise<number | null> {
  const url = new URL(KAKAO);
  url.searchParams.set("origin", origin);
  url.searchParams.set("destination", destination);
  url.searchParams.set("priority", "RECOMMEND");
  if (avoid) url.searchParams.set("avoid", avoid);

  const res = await fetch(url, { headers: { Authorization: `KakaoAK ${key}` } });
  if (!res.ok) return null;

  const body = await res.json();
  const route = body?.routes?.[0];
  // result_code 0이 정상. 길이 없으면 여기서 걸린다.
  if (!route || route.result_code !== 0) return null;
  const sec = route?.summary?.duration;
  return typeof sec === "number" ? Math.round(sec / 60) : null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const key = Deno.env.get("KAKAO_MOBILITY_REST_KEY");
  // 키가 없으면 **비교하지 않는다.** 화면은 근거가 없으면 모달을 띄우지 않는다.
  if (!key) return Response.json({ ok: false, reason: "no_key" }, { status: 200 });

  let from: number[], to: number[];
  try {
    const b = await req.json();
    from = b.from; // [lat, lng] 출발 (현재 위치)
    to = b.to; // [lat, lng] 거점
    if (from?.length !== 2 || to?.length !== 2) throw new Error("bad coords");
  } catch {
    return Response.json({ ok: false, reason: "bad_request" }, { status: 400 });
  }

  // 카카오는 경도,위도 순이다. 뒤집으면 조용히 엉뚱한 곳을 잰다.
  const origin = `${from[1]},${from[0]}`;
  const destination = `${to[1]},${to[0]}`;

  const [highwayMin, routeMin] = await Promise.all([
    ask(key, origin, destination), // 기본 — 고속도로 포함
    ask(key, origin, destination, "motorway"), // 고속도로 회피 = 국도 위주
  ]);

  // 둘 중 하나라도 없으면 비교가 성립하지 않는다. 반쪽 근거로 설득하지 않는다.
  if (highwayMin === null || routeMin === null) {
    return Response.json({ ok: false, reason: "no_route" }, { status: 200 });
  }
  // 국도가 더 빠르면 '느린 길을 권하는' 이 모달의 전제가 깨진다. 띄우지 않는다.
  if (routeMin <= highwayMin) {
    return Response.json({ ok: false, reason: "not_slower" }, { status: 200 });
  }

  return Response.json({ ok: true, highwayMin, routeMin });
});

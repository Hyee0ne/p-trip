// CO-06 거점 장소검색 — 카카오 로컬 API.
//
// ⚠ REST 키는 **여기에만** 있다. 앱 번들에 넣지 않는다 (계정 할당량에 묶인 키다).
// ⚠ 돌려주는 건 **이름·주소·좌표뿐**이다. 전화번호·카테고리·place_url을 넘기지 않는다 —
//    거점은 '위치 좌표 입력값'일 뿐이고(원칙 4), 안 쓸 값을 주면 쓰고 싶어진다.
// ⚠ 검색 범위를 **막지 않는다.** "어디서 예약했든 상관없어요"가 이 화면의 안내문이다.
//    현재 위치를 주면 가까운 순으로 정렬만 한다.

const KAKAO = "https://dapi.kakao.com/v2/local/search/keyword.json";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const key = Deno.env.get("KAKAO_REST_API_KEY");
  if (!key) return Response.json({ ok: false, reason: "no_key" }, { status: 200 });

  let query: string, lat: number | null, lng: number | null;
  try {
    const b = await req.json();
    query = String(b.query ?? "").trim();
    lat = typeof b.lat === "number" ? b.lat : null;
    lng = typeof b.lng === "number" ? b.lng : null;
    if (!query) throw new Error("empty");
  } catch {
    return Response.json({ ok: false, reason: "bad_request" }, { status: 400 });
  }

  const url = new URL(KAKAO);
  url.searchParams.set("query", query);
  url.searchParams.set("size", "12");
  // 위치를 알면 가까운 순으로. 몰라도 검색은 된다.
  if (lat !== null && lng !== null) {
    url.searchParams.set("x", String(lng));
    url.searchParams.set("y", String(lat));
    url.searchParams.set("sort", "distance");
  }

  const res = await fetch(url, { headers: { Authorization: `KakaoAK ${key}` } });
  if (!res.ok) return Response.json({ ok: false, reason: "upstream" }, { status: 200 });

  const body = await res.json();
  const places = (body?.documents ?? [])
    .map((d: Record<string, string>) => ({
      name: d.place_name,
      // 도로명이 없는 곳이 있다. 그때는 지번을 쓴다 — 빈 줄을 두지 않는다.
      addr: d.road_address_name || d.address_name || "",
      lat: Number(d.y),
      lng: Number(d.x),
      // 거리는 정렬했을 때만 온다. 없으면 null — 0으로 채우지 않는다.
      distanceM: d.distance ? Number(d.distance) : null,
    }))
    .filter((p: { lat: number; lng: number }) => Number.isFinite(p.lat) && Number.isFinite(p.lng));

  return Response.json({ ok: true, places });
});

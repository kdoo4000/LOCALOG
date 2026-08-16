import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "npm:@supabase/server@1.3.0";

const mapClientId = Deno.env.get("NAVER_MAP_CLIENT_ID") ?? "";
const mapClientSecret = Deno.env.get("NAVER_MAP_CLIENT_SECRET") ?? "";
const searchClientId =
  Deno.env.get("NAVER_SEARCH_CLIENT_ID") ??
  Deno.env.get("NAVER_OPENAPI_CLIENT_ID") ??
  "";
const searchClientSecret =
  Deno.env.get("NAVER_SEARCH_CLIENT_SECRET") ??
  Deno.env.get("NAVER_OPENAPI_CLIENT_SECRET") ??
  "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const hardExcludedKeywords = [
  "매표소",
  "티켓",
  "ticket",
  "주차장",
  "parking",
  "게이트",
  "입구",
  "출구",
  "화장실",
  "안내소",
  "관리사무소",
];

const travelFriendlyKeywords = [
  "관광",
  "전망",
  "공원",
  "박물관",
  "미술관",
  "전시",
  "갤러리",
  "궁",
  "시장",
  "거리",
  "골목",
  "해변",
  "해수욕장",
  "테마파크",
  "타워",
  "쇼핑",
  "기념품",
  "카페",
  "커피",
  "디저트",
  "베이커리",
  "맛집",
  "음식",
  "식당",
  "레스토랑",
];

type Point = { lat: number; lng: number };
type JsonRecord = Record<string, unknown>;

const authenticatedHandler = withSupabase(
  { auth: "user" },
  async (request: Request, context) => {
    if (request.method !== "GET") {
      return textResponse("Method not allowed", 405);
    }

    try {
      const { data: quotaAvailable, error: quotaError } =
        await context.supabase.rpc("consume_naver_proxy_quota");
      if (quotaError) {
        console.error("naver-proxy quota check failed", quotaError);
        return textResponse("Unable to verify request quota", 503);
      }
      if (!quotaAvailable) {
        return textResponse("Too many requests", 429, {
          "Retry-After": "60",
        });
      }

      const url = new URL(request.url);
      const action = url.pathname.split("/").filter(Boolean).at(-1);
      switch (action) {
        case "health":
          return jsonResponse({
            ok: true,
            mapConfigured: Boolean(mapClientId && mapClientSecret),
            searchConfigured: Boolean(searchClientId && searchClientSecret),
          });
        case "static-map":
          return await handleStaticMap(url);
        case "place-candidates":
          return await handlePlaceCandidates(url);
        case "place-search":
          return await handlePlaceSearch(url);
        default:
          return textResponse("Not found", 404);
      }
    } catch (error) {
      console.error("naver-proxy request failed", error);
      return jsonResponse({ error: String(error) }, 500);
    }
  },
);

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const response = await authenticatedHandler(request);
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(corsHeaders)) {
    headers.set(name, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
});

async function handleStaticMap(requestUrl: URL): Promise<Response> {
  requireMapConfiguration();
  const points = parsePoints(requestUrl.searchParams.get("points"));
  if (points.length === 0 || points.length > 100) {
    return textResponse("points must contain between 1 and 100 coordinates", 400);
  }

  const response = await fetch(buildStaticMapUrl(points), {
    headers: mapHeaders(),
  });
  return new Response(response.body, {
    status: response.status,
    headers: {
      ...corsHeaders,
      "Content-Type":
        response.headers.get("content-type") ?? "application/octet-stream",
      "Cache-Control": "private, max-age=60",
    },
  });
}

async function handlePlaceSearch(requestUrl: URL): Promise<Response> {
  const query = (requestUrl.searchParams.get("query") ?? "").trim();
  if (query.length < 2 || query.length > 100) {
    return textResponse("query must contain between 2 and 100 characters", 400);
  }
  if (!searchClientId || !searchClientSecret) {
    return jsonResponse({ candidates: [], hasLocalSearch: false });
  }

  const origin = parseOrigin(requestUrl);
  const items = await fetchLocalSearch(query, 10);
  const candidates = rankItems(items, origin, query)
    .slice(0, 8)
    .map((item) => toPlaceCandidate(item, "search"));
  return jsonResponse({ candidates, hasLocalSearch: true });
}

async function handlePlaceCandidates(requestUrl: URL): Promise<Response> {
  requireMapConfiguration();
  const origin = parseOrigin(requestUrl);
  if (!origin) {
    return textResponse("valid lat and lng query parameters are required", 400);
  }

  const reverse = await fetchReverseGeocode(origin);
  const addresses = buildAddressCandidates(reverse, origin);
  if (!searchClientId || !searchClientSecret) {
    return jsonResponse({
      candidates: addresses,
      addressCandidates: addresses,
      hasLocalSearch: false,
    });
  }

  const queries = buildSearchQueries(reverse).slice(0, 4);
  const groups = await Promise.all(
    queries.map((query) => fetchLocalSearch(query, 5)),
  );
  const places = rankItems(groups.flat(), origin)
    .filter((item) => item.score >= 20)
    .slice(0, 5)
    .map((item) => toPlaceCandidate(item, "local"));

  return jsonResponse({
    candidates: places.length > 0 ? places : addresses,
    addressCandidates: addresses,
    hasLocalSearch: true,
  });
}

function requireMapConfiguration(): void {
  if (!mapClientId || !mapClientSecret) {
    throw new Error("Naver Maps secrets are not configured");
  }
}

function parseOrigin(url: URL): Point | null {
  const lat = Number.parseFloat(url.searchParams.get("lat") ?? "");
  const lng = Number.parseFloat(url.searchParams.get("lng") ?? "");
  if (
    !Number.isFinite(lat) ||
    !Number.isFinite(lng) ||
    lat < -90 ||
    lat > 90 ||
    lng < -180 ||
    lng > 180
  ) {
    return null;
  }
  return { lat, lng };
}

async function fetchReverseGeocode(origin: Point): Promise<JsonRecord> {
  const url = new URL(
    "https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc",
  );
  url.searchParams.set("coords", `${origin.lng},${origin.lat}`);
  url.searchParams.set("sourcecrs", "epsg:4326");
  url.searchParams.set("orders", "roadaddr,addr,admcode,legalcode");
  url.searchParams.set("output", "json");

  const response = await fetch(url, { headers: mapHeaders() });
  const body = await response.text();
  if (!response.ok) {
    throw new Error(`Reverse geocoding failed (${response.status}). ${body}`);
  }
  return JSON.parse(body) as JsonRecord;
}

async function fetchLocalSearch(
  query: string,
  display: number,
): Promise<JsonRecord[]> {
  const url = new URL("https://openapi.naver.com/v1/search/local.json");
  url.searchParams.set("query", query);
  url.searchParams.set("display", String(Math.min(Math.max(display, 1), 10)));
  url.searchParams.set("start", "1");
  url.searchParams.set("sort", "comment");

  const response = await fetch(url, {
    headers: {
      "X-Naver-Client-Id": searchClientId,
      "X-Naver-Client-Secret": searchClientSecret,
    },
  });
  if (!response.ok) {
    console.warn("Naver local search failed", response.status);
    return [];
  }
  const json = (await response.json()) as JsonRecord;
  return Array.isArray(json.items) ? (json.items as JsonRecord[]) : [];
}

function rankItems(
  items: JsonRecord[],
  origin: Point | null,
  query = "",
): Array<JsonRecord & { score: number; distanceMeters: number | null }> {
  const normalizedQuery = cleanText(query).toLowerCase();
  const byKey = new Map<
    string,
    JsonRecord & { score: number; distanceMeters: number | null }
  >();

  for (const item of items) {
    const name = cleanText(item.title);
    const category = cleanText(item.category);
    const address = cleanText(item.roadAddress || item.address);
    if (!name || !address) continue;

    const haystack = `${name} ${category} ${address}`.toLowerCase();
    if (hardExcludedKeywords.some((keyword) => haystack.includes(keyword))) {
      continue;
    }

    const coordinates = localCoordinates(item);
    const distanceMeters =
      origin && coordinates
        ? haversineMeters(origin, coordinates)
        : null;
    let score = travelFriendlyKeywords.some((keyword) =>
        haystack.includes(keyword)
      )
      ? 35
      : 0;
    if (normalizedQuery) {
      if (name.toLowerCase() === normalizedQuery) score += 120;
      else if (name.toLowerCase().includes(normalizedQuery)) score += 80;
      else if (haystack.includes(normalizedQuery)) score += 25;
    }
    if (distanceMeters != null) {
      if (distanceMeters <= 100) score += 45;
      else if (distanceMeters <= 300) score += 25;
      else if (distanceMeters > 1000) score -= 40;
    }

    const key = `${name}_${address}`;
    const ranked = { ...item, score, distanceMeters };
    if (!byKey.has(key) || byKey.get(key)!.score < score) {
      byKey.set(key, ranked);
    }
  }
  return [...byKey.values()].sort((a, b) => b.score - a.score);
}

function toPlaceCandidate(
  item: JsonRecord & { distanceMeters?: number | null },
  prefix: string,
): JsonRecord {
  const name = cleanText(item.title);
  const address = cleanText(item.roadAddress || item.address);
  const coordinates = localCoordinates(item);
  return {
    id: `${prefix}_${name}_${address}`,
    name,
    address,
    category: cleanText(item.category),
    source: "naver_local_search",
    distanceMeters:
      item.distanceMeters == null ? null : Math.round(item.distanceMeters),
    latitude: coordinates?.lat ?? null,
    longitude: coordinates?.lng ?? null,
  };
}

function buildSearchQueries(reverse: JsonRecord): string[] {
  const results = Array.isArray(reverse.results)
    ? (reverse.results as JsonRecord[])
    : [];
  const values = results.map((result) =>
    [...regionNames(result.region), ...landNames(result.land)].join(" ")
  );
  return [...new Set(values.filter(Boolean))];
}

function buildAddressCandidates(
  reverse: JsonRecord,
  origin: Point,
): JsonRecord[] {
  const results = Array.isArray(reverse.results)
    ? (reverse.results as JsonRecord[])
    : [];
  const seen = new Set<string>();
  const candidates: JsonRecord[] = [];
  for (const result of results) {
    const address = [
      ...regionNames(result.region),
      ...landNames(result.land),
    ].join(" ");
    if (!address || seen.has(address)) continue;
    seen.add(address);
    const source = String(result.name ?? "reverse_geocode");
    candidates.push({
      id: `address_${source}_${address}`,
      name: address,
      address,
      category: addressCategory(source),
      source: "naver_reverse_geocode",
      latitude: origin.lat,
      longitude: origin.lng,
    });
  }
  return candidates;
}

function regionNames(value: unknown): string[] {
  const region = asRecord(value);
  return ["area1", "area2", "area3", "area4"]
    .map((key) => cleanText(asRecord(region[key]).name))
    .filter(Boolean);
}

function landNames(value: unknown): string[] {
  const land = asRecord(value);
  const names = [cleanText(land.name)].filter(Boolean);
  const number1 = cleanText(land.number1);
  const number2 = cleanText(land.number2);
  if (number1) names.push(number2 ? `${number1}-${number2}` : number1);
  return names;
}

function addressCategory(source: string): string {
  switch (source) {
    case "roadaddr":
      return "도로명 주소";
    case "addr":
      return "지번 주소";
    case "admcode":
      return "행정 구역";
    default:
      return "주소";
  }
}

function buildStaticMapUrl(points: Point[]): URL {
  const bounds = points.reduce(
    (value, point) => ({
      minLat: Math.min(value.minLat, point.lat),
      maxLat: Math.max(value.maxLat, point.lat),
      minLng: Math.min(value.minLng, point.lng),
      maxLng: Math.max(value.maxLng, point.lng),
    }),
    {
      minLat: points[0].lat,
      maxLat: points[0].lat,
      minLng: points[0].lng,
      maxLng: points[0].lng,
    },
  );
  const url = new URL("https://maps.apigw.ntruss.com/map-static/v2/raster");
  url.searchParams.set(
    "center",
    `${(bounds.minLng + bounds.maxLng) / 2},${
      (bounds.minLat + bounds.maxLat) / 2
    }`,
  );
  url.searchParams.set("level", String(estimateLevel(bounds, points.length)));
  url.searchParams.set("w", "720");
  url.searchParams.set("h", "420");
  for (const point of points) {
    url.searchParams.append(
      "markers",
      `type:d|size:mid|pos:${point.lng} ${point.lat}|color:red`,
    );
  }
  return url;
}

function parsePoints(value: string | null): Point[] {
  if (!value) return [];
  return value
    .split(";")
    .map((item) => {
      const [lat, lng] = item.split(",").map(Number.parseFloat);
      return { lat, lng };
    })
    .filter(
      (point) =>
        Number.isFinite(point.lat) &&
        Number.isFinite(point.lng) &&
        point.lat >= -90 &&
        point.lat <= 90 &&
        point.lng >= -180 &&
        point.lng <= 180,
    );
}

function estimateLevel(
  bounds: { minLat: number; maxLat: number; minLng: number; maxLng: number },
  count: number,
): number {
  if (count <= 1) return 15;
  const span = Math.max(
    Math.abs(bounds.maxLat - bounds.minLat),
    Math.abs(bounds.maxLng - bounds.minLng),
  );
  if (span >= 2) return 7;
  if (span >= 1) return 8;
  if (span >= 0.5) return 9;
  if (span >= 0.25) return 10;
  if (span >= 0.12) return 11;
  if (span >= 0.06) return 12;
  if (span >= 0.03) return 13;
  if (span >= 0.015) return 14;
  return 15;
}

function localCoordinates(item: JsonRecord): Point | null {
  const lat = normalizeCoordinate(item.mapy, "lat");
  const lng = normalizeCoordinate(item.mapx, "lng");
  return Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : null;
}

function normalizeCoordinate(value: unknown, axis: "lat" | "lng"): number {
  const numeric = Number.parseFloat(String(value ?? ""));
  if (!Number.isFinite(numeric)) return Number.NaN;
  const candidates = [numeric, numeric / 1e7, numeric / 1e6, numeric / 1e5];
  return (
    candidates.find((candidate) =>
      axis === "lat"
        ? candidate >= 30 && candidate <= 45
        : candidate >= 120 && candidate <= 135
    ) ?? Number.NaN
  );
}

function haversineMeters(a: Point, b: Point): number {
  const radius = 6371000;
  const dLat = radians(b.lat - a.lat);
  const dLng = radians(b.lng - a.lng);
  const value =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(a.lat)) *
      Math.cos(radians(b.lat)) *
      Math.sin(dLng / 2) ** 2;
  return radius * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
}

function radians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

function mapHeaders(): HeadersInit {
  return {
    "X-NCP-APIGW-API-KEY-ID": mapClientId,
    "X-NCP-APIGW-API-KEY": mapClientSecret,
  };
}

function cleanText(value: unknown): string {
  return String(value ?? "")
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .trim();
}

function asRecord(value: unknown): JsonRecord {
  return value && typeof value === "object" ? (value as JsonRecord) : {};
}

function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: { ...corsHeaders, "Cache-Control": "no-store" },
  });
}

function textResponse(
  body: string,
  status: number,
  extraHeaders: HeadersInit = {},
): Response {
  return new Response(body, {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
      ...extraHeaders,
    },
  });
}

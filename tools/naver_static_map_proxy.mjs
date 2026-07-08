import http from 'node:http';
import { URL } from 'node:url';

const port = Number.parseInt(process.env.PORT ?? '8787', 10);
const mapClientId = process.env.NAVER_MAP_CLIENT_ID;
const mapClientSecret = process.env.NAVER_MAP_CLIENT_SECRET;
const searchClientId =
  process.env.NAVER_SEARCH_CLIENT_ID ?? process.env.NAVER_OPENAPI_CLIENT_ID;
const searchClientSecret =
  process.env.NAVER_SEARCH_CLIENT_SECRET ??
  process.env.NAVER_OPENAPI_CLIENT_SECRET;

if (!mapClientId || !mapClientSecret) {
  console.error(
    'Set NAVER_MAP_CLIENT_ID and NAVER_MAP_CLIENT_SECRET before starting the proxy.',
  );
  process.exit(1);
}

const server = http.createServer(async (request, response) => {
  setCorsHeaders(response);

  try {
    if (request.method === 'OPTIONS') {
      response.writeHead(204);
      response.end();
      return;
    }

    const requestUrl = new URL(request.url ?? '/', `http://localhost:${port}`);
    if (request.method !== 'GET') {
      sendText(response, 404, 'Not found');
      return;
    }

    if (requestUrl.pathname === '/static-map') {
      await handleStaticMap(requestUrl, response);
      return;
    }

    if (requestUrl.pathname === '/place-candidates') {
      await handlePlaceCandidates(requestUrl, response);
      return;
    }

    sendText(response, 404, 'Not found');
  } catch (error) {
    sendJson(response, 500, { error: String(error) });
  }
});

server.listen(port, () => {
  console.log(`Naver Maps proxy listening on http://localhost:${port}`);
});

async function handleStaticMap(requestUrl, response) {
  const points = parsePoints(requestUrl.searchParams.get('points'));
  if (points.length === 0) {
    sendText(response, 400, 'points query parameter is required.');
    return;
  }

  const naverUrl = buildNaverStaticMapUrl({ points });
  const naverResponse = await fetch(naverUrl, {
    headers: mapHeaders(),
  });

  const bytes = Buffer.from(await naverResponse.arrayBuffer());
  response.writeHead(naverResponse.status, {
    'content-type':
      naverResponse.headers.get('content-type') ?? 'application/octet-stream',
    'cache-control': 'no-store',
  });
  response.end(bytes);
}

async function handlePlaceCandidates(requestUrl, response) {
  const lat = Number.parseFloat(requestUrl.searchParams.get('lat') ?? '');
  const lng = Number.parseFloat(requestUrl.searchParams.get('lng') ?? '');
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    sendText(response, 400, 'lat and lng query parameters are required.');
    return;
  }

  const reverseGeocodeJson = await fetchReverseGeocode({ lat, lng });
  const addressCandidates = buildAddressCandidates(reverseGeocodeJson);
  const placeCandidates = await searchLocalPlaceCandidates(reverseGeocodeJson);

  sendJson(response, 200, {
    candidates:
      placeCandidates.length > 0 ? placeCandidates : addressCandidates,
    addressCandidates,
    hasLocalSearch: Boolean(searchClientId && searchClientSecret),
  });
}

async function fetchReverseGeocode({ lat, lng }) {
  const response = await fetch(buildNaverReverseGeocodeUrl({ lat, lng }), {
    headers: mapHeaders(),
  });
  const body = await response.text();
  if (!response.ok) {
    throw new Error(`Reverse geocoding failed (${response.status}). ${body}`);
  }

  return JSON.parse(body);
}

async function searchLocalPlaceCandidates(reverseGeocodeJson) {
  if (!searchClientId || !searchClientSecret) {
    return [];
  }

  const queries = buildLocalSearchQueries(reverseGeocodeJson);
  const itemGroups = await Promise.all(queries.map(fetchLocalSearchItems));
  const items = itemGroups.flatMap((queryItems, index) =>
    queryItems.map((item) => ({ ...item, query: queries[index] })),
  );
  const addressTargets = buildAddressSearchTargets(reverseGeocodeJson);

  return rankLocalItems(items, addressTargets)
    .filter((item) => item.score >= 45)
    .slice(0, 5)
    .map((item) => ({
      id: `local_${cleanText(item.title)}_${item.roadAddress || item.address}`,
      name: cleanText(item.title),
      address: item.roadAddress || item.address || '',
      category: cleanText(item.category ?? ''),
      source: 'naver_local_search',
    }));
}

async function fetchLocalSearchItems(query) {
  const url = new URL('https://openapi.naver.com/v1/search/local.json');
  url.searchParams.set('query', query);
  url.searchParams.set('display', '5');
  url.searchParams.set('start', '1');
  url.searchParams.set('sort', 'random');

  const response = await fetch(url, {
    headers: {
      'X-Naver-Client-Id': searchClientId,
      'X-Naver-Client-Secret': searchClientSecret,
    },
  });
  if (!response.ok) {
    return [];
  }

  const json = await response.json();
  return Array.isArray(json?.items) ? json.items : [];
}

function buildLocalSearchQueries(reverseGeocodeJson) {
  return buildAddressSearchTargets(reverseGeocodeJson)
    .map((target) => target.query)
    .slice(0, 8);
}

function buildAddressSearchTargets(reverseGeocodeJson) {
  const results = Array.isArray(reverseGeocodeJson?.results)
    ? reverseGeocodeJson.results
    : [];
  const targets = [];
  for (const result of results) {
    const region = regionNames(result?.region);
    const land = landNames(result?.land);
    const fullAddress = [...region, ...land].join(' ');
    if (fullAddress) {
      targets.push({
        query: fullAddress,
        tokens: addressTokens(fullAddress),
        weight: addressWeight(result?.name),
      });
    }

    const roadOrDong = [...region.slice(0, 3), result?.land?.name ?? '']
      .filter(Boolean)
      .join(' ');
    if (roadOrDong) {
      targets.push({
        query: roadOrDong,
        tokens: addressTokens(roadOrDong),
        weight: Math.max(1, addressWeight(result?.name) - 1),
      });
    }
  }

  return dedupeBy(
    targets.filter((target) => target.query && target.tokens.length > 0),
    (target) => target.query,
  );
}

function rankLocalItems(items, addressTargets) {
  const byKey = new Map();
  for (const item of items) {
    const name = cleanText(item.title);
    const address = item.roadAddress || item.address || '';
    if (!name || !address) {
      continue;
    }

    const key = `${name}_${address}`;
    const score = localItemScore(item, addressTargets);
    const current = byKey.get(key);
    if (!current || score > current.score) {
      byKey.set(key, { ...item, score });
    }
  }

  return [...byKey.values()].sort((a, b) => b.score - a.score);
}

function localItemScore(item, addressTargets) {
  const address = `${item.roadAddress ?? ''} ${item.address ?? ''}`;
  const itemTokens = addressTokens(address);
  let bestScore = 0;
  for (const target of addressTargets) {
    let matched = 0;
    for (const token of target.tokens) {
      if (itemTokens.includes(token)) {
        matched += 1;
      }
    }

    const ratio = matched / target.tokens.length;
    const exactBonus = address.includes(target.query) ? 5 : 0;
    bestScore = Math.max(
      bestScore,
      ratio * 100 + matched * 8 + target.weight * 4 + exactBonus,
    );
  }

  return bestScore;
}

function buildAddressCandidates(reverseGeocodeJson) {
  const results = Array.isArray(reverseGeocodeJson?.results)
    ? reverseGeocodeJson.results
    : [];
  return results
    .map((result) => addressCandidateFromReverseGeocodeResult(result))
    .filter(Boolean);
}

function addressCandidateFromReverseGeocodeResult(result) {
  const source = result?.name ?? 'reverse_geocode';
  const address = dedupe([
    ...regionNames(result?.region),
    ...landNames(result?.land),
  ]).join(' ');
  if (!address) {
    return null;
  }

  return {
    id: `address_${source}_${address}`,
    name: address,
    address,
    category: addressTitleForSource(source),
    source: 'naver_reverse_geocode',
  };
}

function buildNaverReverseGeocodeUrl({ lat, lng }) {
  const url = new URL(
    'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc',
  );
  url.searchParams.set('coords', `${lng},${lat}`);
  url.searchParams.set('sourcecrs', 'epsg:4326');
  url.searchParams.set('orders', 'roadaddr,addr,admcode,legalcode');
  url.searchParams.set('output', 'json');
  return url;
}

function buildNaverStaticMapUrl({ points }) {
  const bounds = getBounds(points);
  const center = {
    lat: (bounds.minLat + bounds.maxLat) / 2,
    lng: (bounds.minLng + bounds.maxLng) / 2,
  };
  const url = new URL('https://maps.apigw.ntruss.com/map-static/v2/raster');
  url.searchParams.set('center', `${center.lng},${center.lat}`);
  url.searchParams.set('level', `${estimateLevel(bounds, points.length)}`);
  url.searchParams.set('w', '720');
  url.searchParams.set('h', '420');
  for (const point of points) {
    url.searchParams.append(
      'markers',
      `type:d|size:mid|pos:${point.lng} ${point.lat}|color:red`,
    );
  }
  return url;
}

function parsePoints(value) {
  if (!value) {
    return [];
  }

  return value
    .split(';')
    .map((item) => {
      const [latText, lngText] = item.split(',');
      return {
        lat: Number.parseFloat(latText),
        lng: Number.parseFloat(lngText),
      };
    })
    .filter((point) => Number.isFinite(point.lat) && Number.isFinite(point.lng));
}

function regionNames(region) {
  return ['area1', 'area2', 'area3', 'area4']
    .map((key) => region?.[key]?.name ?? '')
    .filter(Boolean);
}

function landNames(land) {
  const names = [];
  if (land?.name) {
    names.push(land.name);
  }

  const number1 = land?.number1 ?? '';
  const number2 = land?.number2 ?? '';
  if (number1 && number2) {
    names.push(`${number1}-${number2}`);
  } else if (number1) {
    names.push(number1);
  }

  return names;
}

function addressTitleForSource(source) {
  switch (source) {
    case 'roadaddr':
      return 'Road address';
    case 'addr':
      return 'Parcel address';
    case 'admcode':
      return 'Administrative area';
    case 'legalcode':
      return 'Legal area';
    default:
      return 'Address';
  }
}

function addressWeight(source) {
  switch (source) {
    case 'roadaddr':
      return 4;
    case 'addr':
      return 3;
    case 'admcode':
      return 2;
    case 'legalcode':
      return 1;
    default:
      return 1;
  }
}

function addressTokens(value) {
  return cleanText(value)
    .replace(/[(),]/g, ' ')
    .split(/\s+/)
    .map((token) => token.trim())
    .filter((token) => token.length > 0);
}

function getBounds(points) {
  return points.reduce(
    (bounds, point) => ({
      minLat: Math.min(bounds.minLat, point.lat),
      maxLat: Math.max(bounds.maxLat, point.lat),
      minLng: Math.min(bounds.minLng, point.lng),
      maxLng: Math.max(bounds.maxLng, point.lng),
    }),
    {
      minLat: points[0].lat,
      maxLat: points[0].lat,
      minLng: points[0].lng,
      maxLng: points[0].lng,
    },
  );
}

function estimateLevel(bounds, pointCount) {
  if (pointCount <= 1) {
    return 15;
  }

  const span = Math.max(
    Math.abs(bounds.maxLat - bounds.minLat),
    Math.abs(bounds.maxLng - bounds.minLng),
  );
  if (span >= 2.0) return 7;
  if (span >= 1.0) return 8;
  if (span >= 0.5) return 9;
  if (span >= 0.25) return 10;
  if (span >= 0.12) return 11;
  if (span >= 0.06) return 12;
  if (span >= 0.03) return 13;
  if (span >= 0.015) return 14;
  return 15;
}

function mapHeaders() {
  return {
    'X-NCP-APIGW-API-KEY-ID': mapClientId,
    'X-NCP-APIGW-API-KEY': mapClientSecret,
  };
}

function cleanText(value) {
  return String(value ?? '')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .trim();
}

function dedupe(values) {
  return values.filter((value, index) => values.indexOf(value) === index);
}

function dedupeBy(values, keyOf) {
  const seen = new Set();
  const result = [];
  for (const value of values) {
    const key = keyOf(value);
    if (!seen.has(key)) {
      seen.add(key);
      result.push(value);
    }
  }

  return result;
}

function setCorsHeaders(response) {
  response.setHeader('access-control-allow-origin', '*');
  response.setHeader('access-control-allow-methods', 'GET, OPTIONS');
  response.setHeader('access-control-allow-headers', 'content-type');
}

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  response.end(JSON.stringify(body));
}

function sendText(response, statusCode, body) {
  response.writeHead(statusCode, {
    'content-type': 'text/plain; charset=utf-8',
    'cache-control': 'no-store',
  });
  response.end(body);
}

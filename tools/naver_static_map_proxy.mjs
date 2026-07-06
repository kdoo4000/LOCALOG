import http from 'node:http';
import { URL } from 'node:url';

const port = Number.parseInt(process.env.PORT ?? '8787', 10);
const clientId = process.env.NAVER_MAP_CLIENT_ID;
const clientSecret = process.env.NAVER_MAP_CLIENT_SECRET;

if (!clientId || !clientSecret) {
  console.error(
    'Set NAVER_MAP_CLIENT_ID and NAVER_MAP_CLIENT_SECRET before starting the proxy.',
  );
  process.exit(1);
}

const server = http.createServer(async (request, response) => {
  setCorsHeaders(response);

  if (request.method === 'OPTIONS') {
    response.writeHead(204);
    response.end();
    return;
  }

  const requestUrl = new URL(request.url ?? '/', `http://localhost:${port}`);
  if (request.method !== 'GET' || requestUrl.pathname !== '/static-map') {
    response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    response.end('Not found');
    return;
  }

  const points = parsePoints(requestUrl.searchParams.get('points'));
  if (points.length === 0) {
    response.writeHead(400, { 'content-type': 'text/plain; charset=utf-8' });
    response.end('points query parameter is required.');
    return;
  }

  const naverUrl = buildNaverStaticMapUrl({ points });
  const naverResponse = await fetch(naverUrl, {
    headers: {
      'X-NCP-APIGW-API-KEY-ID': clientId,
      'X-NCP-APIGW-API-KEY': clientSecret,
    },
  });

  const bytes = Buffer.from(await naverResponse.arrayBuffer());
  response.writeHead(naverResponse.status, {
    'content-type':
      naverResponse.headers.get('content-type') ?? 'application/octet-stream',
    'cache-control': 'no-store',
  });
  response.end(bytes);
});

server.listen(port, () => {
  console.log(`Naver Static Map proxy listening on http://localhost:${port}`);
});

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

function buildNaverStaticMapUrl({ points }) {
  const bounds = getBounds(points);
  const center = {
    lat: (bounds.minLat + bounds.maxLat) / 2,
    lng: (bounds.minLng + bounds.maxLng) / 2,
  };
  const url = new URL(
    'https://maps.apigw.ntruss.com/map-static/v2/raster',
  );
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

function setCorsHeaders(response) {
  response.setHeader('access-control-allow-origin', '*');
  response.setHeader('access-control-allow-methods', 'GET, OPTIONS');
  response.setHeader('access-control-allow-headers', 'content-type');
}

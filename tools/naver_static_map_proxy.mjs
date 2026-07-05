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

  const lat = Number.parseFloat(requestUrl.searchParams.get('lat') ?? '');
  const lng = Number.parseFloat(requestUrl.searchParams.get('lng') ?? '');
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    response.writeHead(400, { 'content-type': 'text/plain; charset=utf-8' });
    response.end('lat and lng query parameters are required.');
    return;
  }

  const naverUrl = buildNaverStaticMapUrl({ lat, lng });
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

function buildNaverStaticMapUrl({ lat, lng }) {
  const url = new URL(
    'https://maps.apigw.ntruss.com/map-static/v2/raster',
  );
  url.searchParams.set('center', `${lng},${lat}`);
  url.searchParams.set('level', '15');
  url.searchParams.set('w', '720');
  url.searchParams.set('h', '420');
  url.searchParams.set(
    'markers',
    `type:d|size:mid|pos:${lng} ${lat}|color:red`,
  );
  return url;
}

function setCorsHeaders(response) {
  response.setHeader('access-control-allow-origin', '*');
  response.setHeader('access-control-allow-methods', 'GET, OPTIONS');
  response.setHeader('access-control-allow-headers', 'content-type');
}

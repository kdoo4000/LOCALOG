import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

for (const edge of [true, false]) {
  const file = edge ? '../supabase/functions/naver-proxy/index.ts' : './naver_static_map_proxy.mjs';
  let source = readFileSync(new URL(file, import.meta.url), 'utf8');
  source = source.replace(/^import .*;\r?\n/gm, '');
  if (edge) source = stripTypeScriptTypes(source);
  const requests = [];
  const env = new Proxy({}, { get: () => 'test' });
  const context = vm.createContext({
    URL, Response, Headers, Buffer, console,
    process: { env, exit: () => assert.fail('Unexpected exit') },
    http: { createServer: () => ({ listen() {} }) },
    Deno: { env: { get: () => 'test' }, serve() {} },
    withSupabase: () => () => {},
    fetch: async (url) => {
      requests.push(new URL(url));
      return Response.json({ items: [] });
    },
  });
  vm.runInContext(source, context);
  const response = { writeHead() {}, end() {} };
  context.response = response;
  await vm.runInContext('handlePlaceSearch(new URL("https://test/place-search?query=황리단길"), response)', context);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].searchParams.get('query'), '황리단길');
  assert.equal(requests[0].searchParams.get('sort'), 'random', file);
  await vm.runInContext(edge ? 'fetchLocalSearch("경주", 5)' : 'fetchLocalSearchItems("경주")', context);
  assert.equal(requests[1].searchParams.get('sort'), 'comment', file);
  console.log(file + ': keyword similarity and nearby default PASS');
}

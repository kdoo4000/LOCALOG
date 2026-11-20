import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { withSupabase } from 'npm:@supabase/server@1.3.0';
import { syncKakaoFriends, KakaoFriendsError } from './sync.mjs';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
});
const handler = withSupabase({ auth: 'user' }, async (request, context) => {
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  let body;
  try { body = await request.json(); } catch { return json({ error: 'invalid_body' }, 400); }
  const userId = String(context.userClaims?.id ?? '');
  if (!userId) return json({ error: 'authentication_required' }, 401);
  try {
    return json(await syncKakaoFriends(context.supabaseAdmin, userId, body?.provider_token));
  } catch (error) {
    const code = error instanceof KakaoFriendsError ? error.code : 'kakao_unavailable';
    const consented = error instanceof KakaoFriendsError && error.consented === true;
    console.warn(JSON.stringify({ event: 'kakao_friend_sync_failed', code, consented }));
    return json({ error: code, consented }, consented ? 200 : 400);
  }
});
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  const response = await handler(request);
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(cors)) headers.set(key, value);
  return new Response(response.body, { status: response.status, headers });
});

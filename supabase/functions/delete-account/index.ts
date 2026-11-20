import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { withSupabase } from 'npm:@supabase/server@1.3.0';
import { deleteAccount } from './delete_account.mjs';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
});

const handler = withSupabase({ auth: 'user' }, async (request, context) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  let body;
  try { body = await request.json(); } catch { return json({ error: 'Invalid confirmation' }, 400); }
  if (body?.confirmation !== '회원 탈퇴') return json({ error: 'Confirmation required' }, 400);
  const userId = String(context.userClaims?.id ?? '');
  if (!userId) return json({ error: 'Authentication required' }, 401);
  // A signed JWT can outlive a deleted account; check the Auth record as well.
  const { data, error } = await context.supabaseAdmin.auth.admin.getUserById(userId);
  if (error?.code === 'user_not_found' || (!error && !data.user)) {
    return json({ deleted: true });
  }
  if (error) return json({ error: 'Authentication required' }, 401);
  try {
    await deleteAccount(context.supabaseAdmin, userId);
    return json({ deleted: true });
  } catch {
    console.error('Account deletion failed');
    return json({ error: 'Deletion incomplete. Retry to continue.' }, 503);
  }
});

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  const response = await handler(request);
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(cors)) headers.set(name, value);
  return new Response(response.body, { status: response.status, headers });
});

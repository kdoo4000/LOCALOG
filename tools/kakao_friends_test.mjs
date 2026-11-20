import assert from 'node:assert/strict';
import { syncKakaoFriends } from '../supabase/functions/kakao-friends/sync.mjs';

const user = { identities: [{ provider: 'kakao', identity_data: { sub: '123' } }] };
let calls = [];
const admin = {
  auth: { admin: { getUserById: async () => ({ data: { user } }) } },
  rpc: async (name, args) => { calls.push({ name, args }); return { data: 2 }; },
};
function kakao({ consent = true, id = 123, error = null } = {}) {
  return async (url) => {
    const path = new URL(url).pathname;
    if (path.endsWith('/me')) return Response.json({ id });
    if (path.endsWith('/scopes')) return Response.json({ id, scopes: [{ id: 'friends', agreed: consent }] });
    if (error) return Response.json({ code: error }, { status: 403 });
    const offset = new URL(url).searchParams.get('offset');
    return Response.json(offset === '0'
      ? { elements: [{ id: 456 }], after_url: 'https://kapi.kakao.com/v1/api/talk/friends?offset=100' }
      : { elements: [{ id: 789 }], after_url: null });
  };
}
assert.deepEqual(await syncKakaoFriends(admin, 'user', 'token', kakao()), { consented: true, added: 2 });
assert.deepEqual(calls[0].args.p_friend_ids, []);
assert.deepEqual(calls[1].args, { p_user: 'user', p_kakao_id: '123', p_friend_ids: ['456', '789'] });
calls = [];
for (const [options, code] of [[{ consent: false }, 'consent_required'], [{ id: 999 }, 'identity_mismatch']]) {
  await assert.rejects(syncKakaoFriends(admin, 'user', 'token', kakao(options)), error => error.code === code);
  assert.equal(calls.length, 0);
}
await assert.rejects(syncKakaoFriends(admin, 'user', 'token', kakao({ error: -3 })), error => error.code === 'permission_required' && error.consented === true);
assert.equal(calls.length, 1);
assert.deepEqual(calls[0].args.p_friend_ids, []);
await assert.rejects(syncKakaoFriends(admin, 'user', '', kakao()), error => error.code === 'reauth_required');
calls = [];
const emptyFriends = async (url, options) => new URL(url).pathname.endsWith('/friends')
  ? Response.json({ total_count: 0, after_url: null }) : kakao()(url, options);
await syncKakaoFriends(admin, 'user', 'token', emptyFriends);
assert.equal(calls.length, 2);
assert.deepEqual(calls[1].args.p_friend_ids, []);
console.log('Kakao sync: pagination, verified identity, consent, permissions and missing tokens passed');

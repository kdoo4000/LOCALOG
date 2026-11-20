export class KakaoFriendsError extends Error {
  constructor(code) { super(code); this.code = code; }
}

export async function syncKakaoFriends(admin, userId, token, fetcher = fetch) {
  if (typeof token !== 'string' || !token || token.length > 4096) {
    throw new KakaoFriendsError('reauth_required');
  }
  const get = async (path) => {
    const response = await fetcher(`https://kapi.kakao.com${path}`, {
      headers: { Authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(10000),
    });
    const data = await response.json();
    if (!response.ok) {
      throw new KakaoFriendsError(data.code === -402 ? 'consent_required'
        : data.code === -3 ? 'permission_required'
        : response.status === 401 ? 'reauth_required' : 'kakao_unavailable');
    }
    return data;
  };
  const me = await get('/v2/user/me');
  if (!/^[1-9][0-9]*$/.test(String(me?.id))) {
    throw new KakaoFriendsError('identity_mismatch');
  }
  const { data: account, error: accountError } = await admin.auth.admin.getUserById(userId);
  if (accountError || !account?.user?.identities?.some(identity =>
    identity.provider === 'kakao' && String(identity.identity_data?.sub ?? identity.identity_data?.provider_id) === String(me.id))) {
    throw new KakaoFriendsError('identity_mismatch');
  }
  const consent = await get('/v2/user/scopes?scopes=%5B%22friends%22%5D');
  if (String(consent.id) !== String(me.id) || !consent.scopes?.some(scope => scope.id === 'friends' && scope.agreed === true)) {
    throw new KakaoFriendsError('consent_required');
  }
  // Consent remains valid even when the app cannot retrieve the friend list.
  const { error: consentError } = await admin.rpc('sync_kakao_trip_friends', {
    p_user: userId, p_kakao_id: String(me.id), p_friend_ids: [],
  });
  if (consentError) throw new KakaoFriendsError('sync_failed');
  try {
  const ids = new Set();
  let offset = 0;
  for (let page = 0; ; page++) {
    if (page >= 100) throw new KakaoFriendsError('kakao_unavailable');
    const result = await get(`/v1/api/talk/friends?limit=100&offset=${offset}`);
    const elements = result.elements ?? (result.total_count === 0 ? [] : null);
    if (!Array.isArray(elements)) throw new KakaoFriendsError('kakao_unavailable');
    for (const friend of elements) {
      if (friend.id != null) ids.add(String(friend.id));
    }
    if (!result.after_url) break;
    const next = Number(new URL(result.after_url).searchParams.get('offset'));
    if (!Number.isSafeInteger(next) || next <= offset) throw new KakaoFriendsError('kakao_unavailable');
    offset = next;
  }
  const { data, error } = await admin.rpc('sync_kakao_trip_friends', {
    p_user: userId, p_kakao_id: String(me.id), p_friend_ids: [...ids],
  });
  if (error) throw new KakaoFriendsError('sync_failed');
  return { consented: true, added: data };
  } catch (error) {
    const failure = error instanceof KakaoFriendsError ? error : new KakaoFriendsError('kakao_unavailable');
    failure.consented = true;
    throw failure;
  }
}

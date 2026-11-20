import { test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteAccount } from '../supabase/functions/delete-account/delete_account.mjs';

function fixture({ failure } = {}) {
  let files = Array.from({ length: 205 }, (_, i) => ({
    bucket_id: i % 2 ? 'route-photos' : 'travel-receipts', name: `user/${i}.jpg`,
  }));
  const calls = [];
  const admin = {
    async rpc(name, params) {
      calls.push(name);
      assert.deepEqual(params, { p_user_id: 'verified-user' });
      if (failure === name) return { error: new Error('database unavailable') };
      return { data: name === 'account_deletion_files' ? files.slice(0, 100) : null, error: null };
    },
    storage: { from(bucket) { return { async remove(paths) {
      calls.push('remove');
      if (failure === 'remove') return { error: new Error('storage unavailable') };
      files = files.filter((f) => f.bucket_id !== bucket || !paths.includes(f.name));
      return { error: null };
    } }; } },
  };
  return { admin, calls, remaining: () => files.length };
}

test('removes every page and bucket before deleting the account', async () => {
  const f = fixture();
  await deleteAccount(f.admin, 'verified-user');
  assert.equal(f.remaining(), 0);
  assert.equal(f.calls[0], 'prepare_account_deletion');
  assert.equal(f.calls.at(-1), 'finish_account_deletion');
  assert.equal(f.calls.filter((name) => name === 'account_deletion_files').length, 4);
});

for (const failure of ['prepare_account_deletion', 'account_deletion_files', 'remove']) {
  test(`does not delete account after ${failure} fails`, async () => {
    const f = fixture({ failure });
    await assert.rejects(deleteAccount(f.admin, 'verified-user'));
    assert.ok(!f.calls.includes('finish_account_deletion'));
  });
}

test('retry continues after a partial file deletion', async () => {
  const f = fixture();
  const remove = f.admin.storage.from;
  let attempts = 0;
  f.admin.storage.from = (bucket) => {
    const api = remove(bucket);
    return { remove: (paths) => ++attempts === 2
      ? Promise.resolve({ error: new Error('interrupted') }) : api.remove(paths) };
  };
  await assert.rejects(deleteAccount(f.admin, 'verified-user'));
  assert.ok(f.remaining() > 0 && f.remaining() < 205);
  await deleteAccount(f.admin, 'verified-user');
  assert.equal(f.remaining(), 0);
});

test('does not loop forever or delete account when Storage reports success without removing files', async () => {
  const f = fixture();
  f.admin.storage.from = () => ({ remove: async () => ({ error: null }) });
  await assert.rejects(deleteAccount(f.admin, 'verified-user'), /no progress/);
  assert.ok(!f.calls.includes('finish_account_deletion'));
});

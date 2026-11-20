export async function deleteAccount(admin, userId) {
  const params = { p_user_id: userId };
  const prepared = await admin.rpc('prepare_account_deletion', params);
  if (prepared.error) throw prepared.error;
  let previousPage;
  // Re-read the first page after each removal so accounts with >100 files work.
  while (true) {
    const { data: files, error } = await admin.rpc('account_deletion_files', params);
    if (error) throw error;
    if (!Array.isArray(files)) throw new Error('Invalid file manifest');
    if (files.length === 0) break;
    const page = JSON.stringify(files);
    if (page === previousPage) throw new Error('Storage removal made no progress');
    previousPage = page;
    const buckets = Map.groupBy(files, (file) => file.bucket_id);
    for (const [bucket, entries] of buckets) {
      const result = await admin.storage.from(bucket).remove(entries.map((file) => file.name));
      if (result.error) throw result.error;
    }
  }
  const finished = await admin.rpc('finish_account_deletion', params);
  if (finished.error) throw finished.error;
}

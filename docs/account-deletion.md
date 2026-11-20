# Account deletion

Profile → Settings → 회원 탈퇴 requires typing `회원 탈퇴`. The server derives the account ID from the verified session, never from the request body. Only the server role can execute the deletion RPCs.

On confirmation, shared trips transfer to an accepted, active member (earliest invitation time, then user ID). Trips without another accepted member are deleted. The successor becomes owner and the remaining invitations are retained.

Storage API deletion removes the departing member's photos, avatars, receipts and orphan uploads, plus receipts belonging to trips that will be deleted. Other members' files in transferred trips remain. Database cleanup then deletes the account, profile, authored logs, expenses, shares, follows and invitations. Shared canonical place identities are retained without the departing creator ID when other members reference them.

Other members' expenses keep their original amounts and receipts. Expenses with missing participant shares are excluded from settlement and show a re-registration notice, avoiding incorrect transfers.

Deletion is irreversible. Ownership transfer happens before file removal. A failure can leave a partially processed account; the user must retry the same action to continue. New uploads are blocked while deletion is pending. This does not erase external downloads or historical provider backups.

## Verification

- `node --test tools/account_deletion_test.mjs`: pagination, ordering, storage/database failure and partial retry.
- `flutter test test/account_deletion_tile_test.dart test/trip_settlement_test.dart`: confirmation/cancellation, settlement safety.
- The same Flutter tests also run on Chrome with `--platform chrome`.
- `supabase/tests/account_deletion.sql`: disposable, rolled-back fixtures for transfer selection, file ownership, upload blocking, permissions and relational cleanup. Run on a disposable local Supabase database; its Storage rows simulate API removal and must never be used to delete real files directly.

Production verification additionally checked server-only RPC grants, unauthenticated endpoint rejection and rollback-only relational fixtures. No real user account was deleted. The deployed `main.dart.js` SHA-256 matched the local release build.

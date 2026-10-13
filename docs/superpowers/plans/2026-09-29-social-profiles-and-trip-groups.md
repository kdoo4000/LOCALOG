# Social Profiles and Trip Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give LOCALOG searchable `@handle` profiles and a trip group where the owner invites members, including people who join later through a shared code, while only the owner publishes trip-derived logs.

**Architecture:** Keep profile identity in `profiles`, follows in `user_follows`, and group membership in existing `travel_plan_members`. Add one-use external invitation codes redeemed by an authenticated, atomic database function. The existing plan detail screen is the group surface; no chat or domain-based link is built.

**Tech Stack:** Flutter/Dart, Supabase Postgres/Auth/Storage, Android and iOS platform share menu (`share_plus`).

**Spec:** `docs/superpowers/specs/2026-09-29-social-profiles-and-trip-groups-design.md`

## Global Constraints

- Public handles are lowercase, unique without regard to case, 3–30 characters, using Latin letters, digits, periods, and underscores; no leading/trailing punctuation or consecutive periods. UI prefixes `@`; login remains email/password.
- Existing users receive `u_` plus lowercase base32 of their full UUID as a temporary, collision-free handle. Existing foreign keys remain UUIDs.
- Only the trip owner invites, removes another member, revokes codes, and publishes a log sourced from the trip's planned route. Accepted members may edit the plan and add expenses.
- External codes contain at least 128 random bits, expire after seven days, are one-use, and can be revoked. No trip contents or receipts are visible before membership.
- Do not add chat, domain-based links, a separate trip-post type, or secondary explanation lines beneath menu items.
- Preserve unrelated uncommitted work. Stage only intended hunks. Do not apply the new migration to the remote project until its diff and rollback-only checks are reviewable.

## Review Focus

- Existing UUID-derived handles must be unique and fit the 30-character limit; Task 1 tests this for multiple accounts.
- Two accounts racing for the same edited handle must leave exactly one owner; Task 1 tests the database unique constraint.
- Two recipients redeeming the same code concurrently must yield one accepted membership; Task 4 tests atomic redemption.
- A forwarded, expired, revoked, or reused code must not reveal the private trip or create membership; Task 4 tests each state.
- A non-owner calling the API directly to publish or attach a trip-derived log must fail while a personal log remains allowed; Task 5 tests both paths.

---

### Task 1: Handle identity and follow visibility

**Files:**
- Create: migration produced by `supabase migration new social_handles`
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Create: `lib/features/profile/data/social_repository.dart`
- Test: `test/social_handle_test.dart`; SQL rollback-only integration script in `supabase/tests/social_identity.sql`

**Interfaces:** `SocialRepository.profile(String id)`, `search(String query)`, `followers(String id)`, `following(String id)`, `setFollowing(String id, bool follow)`, and `updateMyProfile({required String handle, required String displayName})`. `SocialPerson` exposes `id`, `displayName`, `handle`, and `avatarPath`.

- [ ] **Step 1: Write failing checks** for valid/invalid handle normalization, UUID backfill length/uniqueness, duplicate-handle update rejection, and authenticated follow-list visibility.
- [ ] **Step 2: Run the checks** with `flutter test test/social_handle_test.dart` and the available Supabase test connection; confirm expected failures.
- [ ] **Step 3: Generate the migration** with `supabase migration new social_handles`; add `profiles.handle`, deterministic backfill and signup trigger update, format/unique constraints, and an authenticated `user_follows` read policy. Implement `SocialRepository` and signup handle input.
- [ ] **Step 4: Re-run the checks** and `flutter analyze --no-pub`; verify that account creation with a taken handle fails cleanly and an existing account can edit its temporary handle.
- [ ] **Step 5: Commit only this task's changes** after inspecting staged hunks.

### Task 2: Social profile and discovery screens

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Create: `lib/features/profile/presentation/public_profile_screen.dart`
- Create: `lib/features/profile/presentation/people_search_screen.dart`
- Modify: `lib/features/route_search/presentation/route_detail_screen.dart`
- Modify: `lib/features/route_search/data/supabase_route_repository.dart`
- Test: `test/social_profile_test.dart`

**Interfaces:** Consume `SocialRepository` and `SocialPerson` from Task 1. `PublicProfileScreen(userId: String)` reads only public logs; `PeopleSearchScreen` returns a selected `SocialPerson` when used by the invitation flow.

- [ ] **Step 1: Write failing widget checks** for `@handle`, follower/following counts and lists, Follow/Following state, handle/display-name search, and route-author-to-profile navigation.
- [ ] **Step 2: Run `flutter test test/social_profile_test.dart`** and confirm the missing behavior.
- [ ] **Step 3: Implement the screens and navigation** using the existing profile and route UI patterns. Show concise labels only; remove the UUID fragment and the false `@displayName` presentation.
- [ ] **Step 4: Run the widget checks and `flutter analyze --no-pub`**; inspect on an Android emulator at narrow width.
- [ ] **Step 5: Commit only this task's changes** after inspecting staged hunks.

### Task 3: Trip group, direct invitations, and member settlement

**Files:**
- Create: migration produced by `supabase migration new trip_group_invitation_rules`
- Modify: `lib/features/trip_planning/data/shared_trip_repository.dart`
- Modify: `lib/features/trip_planning/presentation/trip_invite_screen.dart`
- Modify: `lib/features/trip_planning/presentation/travel_plan_detail_screen.dart`
- Modify: `lib/features/trip_planning/presentation/trip_expenses_screen.dart`
- Test: `test/trip_group_test.dart`; SQL rollback-only integration script in `supabase/tests/trip_group_access.sql`

**Interfaces:** Keep `SharedTripRepository.invite(String planId, String title, String personId)`. Extend existing `TripPerson` with `String handle` and return `Future<List<TripPerson>>` from `members(String planId)` and `searchPeople(String query)`. Accept any registered non-member account when the caller owns the plan. Member expense access remains under the existing membership rules.

- [ ] **Step 1: Write failing checks** for owner-only direct invitation, duplicate invite prevention, accepted member settlement access, and a member list with handles and owner badge.
- [ ] **Step 2: Run focused Flutter and SQL checks** and confirm the current owner-only settlement UI and missing handle states fail.
- [ ] **Step 3: Generate the migration** and enforce owner-only direct invitation in Postgres. Remove follow gating from the invite screen, show members and invitation status in the plan, and expose settlement to accepted members.
- [ ] **Step 4: Re-run focused checks and `flutter analyze --no-pub`**; verify outsider plan/receipt access stays denied.
- [ ] **Step 5: Commit only this task's changes** after inspecting staged hunks.

### Task 4: External invitation code and share

**Files:**
- Create: migration produced by `supabase migration new trip_invitation_codes`
- Modify: `pubspec.yaml`, `pubspec.lock`
- Modify: `lib/features/trip_planning/data/shared_trip_repository.dart`
- Modify: `lib/features/trip_planning/presentation/trip_invite_screen.dart`
- Modify: `lib/features/trip_planning/presentation/travel_plan_screen.dart`
- Create: `lib/features/trip_planning/presentation/trip_code_screen.dart`
- Test: `test/trip_code_test.dart`; SQL rollback-only integration script in `supabase/tests/trip_codes.sql`

**Interfaces:** Add `SharedTripRepository.createCode(String planId): Future<TripCode>` (ID, plaintext code, expiry), `revokeCode(String codeId): Future<void>`, `previewCode(String code): Future<TripCodePreview>` (trip title and owner handle only), and `redeemCode(String code): Future<String>` (joined plan ID). The share action uses `SharePlus.instance.share(ShareParams(text: ...))`.

- [ ] **Step 1: Write failing checks** for owner-only code creation/revocation, 128-bit randomness, seven-day expiry, one-use concurrent redemption, invalid/expired/revoked code, and no private-plan data before join.
- [ ] **Step 2: Run focused Flutter and SQL checks** and confirm failures.
- [ ] **Step 3: Generate the migration** with a private code hash and narrow authenticated functions; add `share_plus`, share text via the OS menu, and an in-app paste/preview/confirm flow after login or signup. Do not add a URL or Kakao SDK.
- [ ] **Step 4: Re-run checks and `flutter analyze --no-pub`**; manually share to KakaoTalk if installed and another target on Android.
- [ ] **Step 5: Commit only this task's changes** after inspecting staged hunks.

### Task 5: Owner-only trip-derived log publishing and final integration

**Files:**
- Create: migration produced by `supabase migration new trip_owner_log_publishing`
- Modify: `lib/features/trip_planning/presentation/travel_plan_detail_screen.dart`
- Modify: `lib/features/trip_planning/presentation/planned_route_log_create_screen.dart`
- Test: `test/trip_log_owner_test.dart`; SQL rollback-only integration script in `supabase/tests/trip_log_owner.sql`

**Interfaces:** A plan-derived log remains a `routes` row with `source_planned_route_id`; `linkCompletedLog(planDayId, logId)` retains its existing signature. Server validation checks the plan owner when this source field is set and when the log is linked.

- [ ] **Step 1: Write failing checks** that a non-owner cannot insert/update or link a trip-derived log, the owner can, and both users can still create unrelated personal logs.
- [ ] **Step 2: Run focused Flutter and SQL checks** and confirm the non-owner path currently passes when it should fail.
- [ ] **Step 3: Generate the migration** with an owner check on trip-derived route creation/update and completed-log linking. Hide and guard the plan's log action for non-owners; remove the redundant helper subtitle in that flow.
- [ ] **Step 4: Run focused checks, all trip/social tests, and `flutter analyze --no-pub`**. Inspect the final owner and member flows on an emulator, including invitation, settlement, and publishing.
- [ ] **Step 5: Review the full diff and commit only this task's changes**. Keep the new remote migration unapplied until its SQL and deployment target are reviewed.

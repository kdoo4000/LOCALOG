# Social profiles and trip groups

## Goal

Make LOCALOG feel like a social travel app: people can find one another by a public `@handle`, follow accounts, and join a trip group to plan and settle expenses together. A trip is the group space; this release does not add chat. Menu items and actions use concise labels without a secondary explanation line.

## References and decisions

- [Discord usernames and display names](https://support.discord.com/hc/en-us/articles/12620128861463-New-Usernames-Display-Names): keep a unique, stable-to-search handle separate from a non-unique display name.
- [WhatsApp group invitations](https://faq.whatsapp.com/3242937609289432/): put membership and invitations in the group, let its owner control invitations and revoke shared invites. LOCALOG uses one-use invitations to limit forwarded codes.
- [KakaoTalk Share concepts](https://developers.kakao.com/docs/ko/kakaotalk-share/common) and [Android Sharesheet](https://developer.android.com/develop/ui/compose/sharing/send): use the platform share menu for an invitation so KakaoTalk and other installed apps can receive it. A Kakao-specific template and SDK are unnecessary for simple text sharing.
- [Flutter App Links](https://docs.flutter.dev/cookbook/navigation/set-up-app-links): automatic install-to-app links require a controlled web domain. Domain-dependent linking is excluded. Share a code to paste in the app; do not claim it is a clickable app link.

## Identity and social profiles

- Each profile has a unique, case-insensitive handle stored without the `@`; UI always displays `@handle`. Allow lowercase Latin letters, digits, periods, and underscores, 3–30 characters. Reject leading/trailing punctuation and consecutive periods. The database owns the uniqueness constraint; the app checks format and gives a clear taken-handle error.
- Display name remains separate and can be non-unique. Existing accounts receive a collision-free temporary handle formed from `u_` plus the lowercase base32 encoding of their full UUID; users can edit it from their profile. New accounts choose a handle during account setup. Existing email/password authentication stays in place; a handle is the public identity and search key, not an email substitute for sign-in.
- Own and public profiles show avatar, display name, `@handle`, follower count, following count, and public logs. Followers and following counts open account lists. Public profiles offer Follow/Following. Search accepts `@handle` and display name. Route author names open their public profile.
- Following is independent of trip membership and invitation eligibility. Unfollowing never removes someone from a trip or changes expense history.

## Trip group

- The existing travel plan is the group. Its detail view brings the plan, member list, invitations, and expense settlement together. Show each member's display name and `@handle`, and distinguish the owner with a short badge. No chat messages, chat table, typing state, or unread count in this release.
- Only the plan owner may send or revoke invitations and remove another member. Any accepted member may view and edit the shared plan and add expenses under the existing membership rules. An invited member explicitly accepts or declines before gaining access.
- The owner can search any registered account by `@handle` or display name and send an in-app invitation. No follow or mutual-follow condition applies. The server enforces owner-only invitation creation; the UI shows statuses and disables duplicate invitations.
- The owner can also create a one-use external invitation for someone who has not joined the app. The platform share menu sends the trip title, inviter handle, and invitation code. The recipient signs up or signs in, enters or pastes the code in the trip area, reviews the trip and inviter, and confirms joining. A valid code joins the recipient to the existing plan without a follow requirement.
- Each external code expires after seven days, can be redeemed once, and can be revoked by the owner. A new code is needed for another recipient. A forwarded code can be claimed by its first holder; the confirmation screen makes the group identity visible before joining. No trip contents or receipts are returned until the code is redeemed and membership is established.
- Only the plan owner may turn a planned route into a published log and attach it back to the trip. Accepted members can continue editing the shared plan, but cannot publish its route as their own log. The existing per-day planned-route-to-log flow remains; this release does not invent a separate whole-trip post type.

## Data and authorization

- Add `handle` to `profiles`, backfill existing rows, and add a unique normalized index plus a format check. Keep the existing UUID as the foreign key and internal identity, so renaming a handle does not affect trips, follows, or expenses. Follow edges and follower/following lists are readable by signed-in users; profile rows continue to exclude private authentication fields such as email.
- Reuse `user_follows` and `travel_plan_members`. Add an external-invitation table containing plan ID, creator, a hash of a randomly generated high-entropy code, expiry, redemption metadata, and revocation state. Store the code only in the creator's share text, not in readable database rows.
- Add narrow server functions for creating, revoking, previewing, and redeeming external invitations. Redemption runs atomically: verify authentication, code hash, expiry, unused state, and membership; create accepted membership and mark the code used in one transaction. Use at least 128 random bits in each code so guessing is infeasible. Owners and accepted members can read only the invitation and member data needed for their plan; outsiders cannot enumerate codes, plan contents, or expense records.
- Tighten the existing direct-invitation policy to owner-only. Preserve pending and accepted invitations created before this change. Existing accepted members keep access even if a follow edge is removed. Keep current expense and receipt authorization tied to trip membership.
- Guard planned-route log creation and linking on the server using the owning plan's `owner_id`, including direct API calls. Do not block a member from creating an unrelated personal log.

## Screens and failure states

- Profile: editable handle and display name; follower/following counts and lists; public profile navigation from author names.
- Trip detail: member avatars/names, owner badge, invitation and planned-route log publishing entry for owner, settlement entry for all accepted members. Do not add descriptive subtitle text beneath every menu or action.
- Invite: registered-user search, pending/accepted status, external code creation, share, and revoke. Trip list offers code entry for recipients, including after account creation.
- Show clear errors for a taken or invalid handle, already-invited account, expired/used/revoked code, missing network, and a plan the user can no longer access. Never show a raw UUID as a user-facing ID.

## Verification

- Migration checks: existing profile backfill is unique; duplicate or malformed handles fail; direct invitation creation by a non-owner fails; code redemption succeeds once and fails after expiry, revocation, and reuse; an outsider cannot read a private plan or its expenses; a trip member cannot publish or attach a log sourced from that trip's planned route.
- Flutter checks: handle formatting/search, follower/following display, owner-only invite controls, code redemption states, and shared trip/settlement navigation. Exercise the OS share menu on Android and confirm KakaoTalk appears when installed.
- Preserve unrelated uncommitted work already in the repository. Applying a remote database migration remains a separate deployment action. No invitation landing page, web domain, or app-link integration is in scope.

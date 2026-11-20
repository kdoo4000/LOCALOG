drop function public.create_trip_invitation_code(uuid);
drop function public.active_trip_invitation_codes(uuid);
drop function public.revoke_trip_invitation_code(uuid);
drop function public.preview_trip_invitation_code(text);
drop function public.redeem_trip_invitation_code(text);

-- Retain historical redemption records without allowing old clients to use codes.
update private.trip_invitation_codes set revoked_at = now()
where revoked_at is null and redeemed_by is null;

do $$
begin
  if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in (
      'create_trip_invitation_code','active_trip_invitation_codes',
      'revoke_trip_invitation_code','preview_trip_invitation_code','redeem_trip_invitation_code')) then
    raise exception 'Invitation code RPCs still available';
  end if;
  if exists(select 1 from private.trip_invitation_codes where redeemed_by is null and revoked_at is null) then
    raise exception 'An old invitation code remains active';
  end if;
end $$;

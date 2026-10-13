create table private.trip_invitation_codes (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.travel_plans(id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz not null,
  redeemed_by uuid references public.profiles(id),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
alter table private.trip_invitation_codes enable row level security;
revoke all on private.trip_invitation_codes from public, anon, authenticated;

create function public.create_trip_invitation_code(p_plan_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_code text := pg_catalog.encode(extensions.gen_random_bytes(16), 'hex');
  v_id uuid;
  v_expiry timestamptz := now() + interval '7 days';
begin
  if not exists (select 1 from public.travel_plans where id = p_plan_id and owner_id = (select auth.uid())) then
    raise exception 'Only the trip owner can create an invitation';
  end if;
  insert into private.trip_invitation_codes(plan_id, code_hash, expires_at)
  values (p_plan_id, pg_catalog.md5(v_code), v_expiry) returning id into v_id;
  return pg_catalog.jsonb_build_object('id', v_id, 'code', v_code, 'expires_at', v_expiry);
end;
$$;
revoke all on function public.create_trip_invitation_code(uuid) from public, anon;
grant execute on function public.create_trip_invitation_code(uuid) to authenticated;

create function public.active_trip_invitation_codes(p_plan_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_codes jsonb;
begin
  if not exists (select 1 from public.travel_plans where id = p_plan_id and owner_id = (select auth.uid())) then
    raise exception 'Only the trip owner can view invitations';
  end if;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', id, 'expires_at', expires_at)
    order by created_at desc), '[]'::jsonb) into v_codes
  from private.trip_invitation_codes
  where plan_id = p_plan_id and expires_at > now() and revoked_at is null and redeemed_by is null;
  return v_codes;
end;
$$;
revoke all on function public.active_trip_invitation_codes(uuid) from public, anon;
grant execute on function public.active_trip_invitation_codes(uuid) to authenticated;

create function public.revoke_trip_invitation_code(p_code_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update private.trip_invitation_codes c set revoked_at = now()
  from public.travel_plans p
  where c.id = p_code_id and p.id = c.plan_id and p.owner_id = (select auth.uid());
  if not found then raise exception 'Invitation not found'; end if;
end;
$$;
revoke all on function public.revoke_trip_invitation_code(uuid) from public, anon;
grant execute on function public.revoke_trip_invitation_code(uuid) to authenticated;

create function public.preview_trip_invitation_code(p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_result jsonb;
begin
  if (select auth.uid()) is null or p_code !~ '^[a-f0-9]{32}$' then
    raise exception 'Invalid invitation';
  end if;
  select pg_catalog.jsonb_build_object('title', p.title, 'owner_handle', owner.handle)
  into v_result
  from private.trip_invitation_codes c
  join public.travel_plans p on p.id = c.plan_id
  join public.profiles owner on owner.id = p.owner_id
  where c.code_hash = pg_catalog.md5(p_code)
    and c.expires_at > now() and c.revoked_at is null and c.redeemed_by is null;
  if v_result is null then raise exception 'Invitation expired or unavailable'; end if;
  return v_result;
end;
$$;
revoke all on function public.preview_trip_invitation_code(text) from public, anon;
grant execute on function public.preview_trip_invitation_code(text) to authenticated;

create function public.redeem_trip_invitation_code(p_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_invite private.trip_invitation_codes%rowtype;
  v_owner uuid;
  v_title text;
begin
  if (select auth.uid()) is null or p_code !~ '^[a-f0-9]{32}$' then
    raise exception 'Invalid invitation';
  end if;
  select * into v_invite from private.trip_invitation_codes
  where code_hash = pg_catalog.md5(p_code) for update;
  if not found or v_invite.expires_at <= now() or v_invite.revoked_at is not null
    or v_invite.redeemed_by is not null then
    raise exception 'Invitation expired or unavailable';
  end if;
  select owner_id, title into v_owner, v_title from public.travel_plans where id = v_invite.plan_id;
  if v_owner = (select auth.uid()) then raise exception 'Already the trip owner'; end if;
  insert into public.travel_plan_members(plan_id, user_id, invited_by, plan_title, status)
  values (v_invite.plan_id, (select auth.uid()), v_owner, v_title, 'accepted')
  on conflict (plan_id, user_id) do update set status = 'accepted'
  where travel_plan_members.status = 'declined';
  if not found then raise exception 'Already invited or joined'; end if;
  update private.trip_invitation_codes set redeemed_by = (select auth.uid()) where id = v_invite.id;
  return v_invite.plan_id;
end;
$$;
revoke all on function public.redeem_trip_invitation_code(text) from public, anon;
grant execute on function public.redeem_trip_invitation_code(text) to authenticated;

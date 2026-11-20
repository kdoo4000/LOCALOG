-- Keep uploads stable while Storage API deletion runs outside the DB transaction.
create function private.guard_account_deletion_write()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  target_owner uuid;
  pending boolean;
begin
  if actor is not null then
    select coalesce((raw_app_meta_data->>'account_deletion_pending')::boolean, false)
      into pending from auth.users where id = actor for share;
    if not found or pending then
      raise exception 'Account deletion in progress' using errcode = '42501';
    end if;
  end if;
  if tg_table_schema = 'storage' and tg_op <> 'DELETE' then
    if new.bucket_id in ('route-photos', 'profile-avatars') then
      select id into target_owner from auth.users
        where id::text = split_part(new.name, '/', 1);
    elsif new.bucket_id = 'travel-receipts' then
      select p.owner_id into target_owner from public.travel_plans p
        where p.id::text = split_part(new.name, '/', 1);
    end if;
    if target_owner is not null then
      select coalesce((raw_app_meta_data->>'account_deletion_pending')::boolean, false)
        into pending from auth.users where id = target_owner for share;
      if pending then
        raise exception 'Account deletion in progress' using errcode = '42501';
      end if;
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function private.guard_account_deletion_write() from public, anon, authenticated;

create trigger guard_account_deletion_upload before insert or update on storage.objects
for each row execute function private.guard_account_deletion_write();

create function public.prepare_account_deletion(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  plan record;
  successor uuid;
begin
  update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
    || '{"account_deletion_pending":true}'::jsonb where id = p_user_id;
  if not found then raise exception 'Account not found'; end if;
  for plan in select id from public.travel_plans where owner_id = p_user_id for update loop
    select user_id into successor from public.travel_plan_members
      where plan_id = plan.id and user_id <> p_user_id and status = 'accepted'
        and exists (select 1 from auth.users u where u.id = user_id
          and coalesce(u.raw_app_meta_data->>'account_deletion_pending', 'false') <> 'true')
      order by created_at, user_id limit 1 for update;
    if successor is not null then
      update public.travel_plans set owner_id = successor where id = plan.id;
      update public.travel_plan_members set invited_by = successor
        where plan_id = plan.id and invited_by = p_user_id;
      delete from public.travel_plan_members where plan_id = plan.id and user_id = successor;
    end if;
  end loop;
end;
$$;

create function public.account_deletion_files(p_user_id uuid)
returns table(bucket_id text, name text)
language sql stable security definer set search_path = '' as $$
  select o.bucket_id, o.name from storage.objects o
  where o.owner_id = p_user_id::text or o.owner = p_user_id
    or (o.bucket_id in ('route-photos', 'profile-avatars')
      and split_part(o.name, '/', 1) = p_user_id::text)
    or (o.bucket_id = 'travel-receipts' and (
      exists (select 1 from public.travel_plans p where p.owner_id = p_user_id
        and p.id::text = split_part(o.name, '/', 1))
      or exists (select 1 from public.travel_expenses e
        where (e.created_by = p_user_id or e.payer_id = p_user_id)
          and (e.receipt_path = o.name or (e.plan_id::text = split_part(o.name, '/', 1)
            and e.id::text = split_part(o.name, '/', 2))))))
  order by o.bucket_id, o.name limit 100;
$$;

create function public.finish_account_deletion(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from auth.users where id = p_user_id
    and raw_app_meta_data->>'account_deletion_pending' = 'true' for update;
  if not found then raise exception 'Account deletion not prepared'; end if;
  if exists (select 1 from public.account_deletion_files(p_user_id)) then
    raise exception 'Account files must be deleted first';
  end if;
  update public.planned_routes set source_author_name = null
    where source_log_id in (select id from public.routes where owner_id = p_user_id);
  delete from public.travel_expenses where created_by = p_user_id or payer_id = p_user_id;
  delete from public.travel_expense_shares where user_id = p_user_id;
  delete from public.travel_plan_members where user_id = p_user_id or invited_by = p_user_id;
  delete from private.trip_invitation_codes where redeemed_by = p_user_id;
  delete from public.routes where owner_id = p_user_id;
  delete from public.travel_plans where owner_id = p_user_id;
  delete from public.place_sources where created_by = p_user_id;
  -- Shared place identities are service data; preserve other members' references.
  delete from public.places p where created_by = p_user_id
    and not exists (select 1 from public.route_places r where r.place_id = p.id)
    and not exists (select 1 from public.planned_route_places r where r.place_id = p.id);
  delete from auth.users where id = p_user_id;
end;
$$;

revoke all on function public.prepare_account_deletion(uuid) from public, anon, authenticated;
revoke all on function public.account_deletion_files(uuid) from public, anon, authenticated;
revoke all on function public.finish_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.prepare_account_deletion(uuid) to service_role;
grant execute on function public.account_deletion_files(uuid) to service_role;
grant execute on function public.finish_account_deletion(uuid) to service_role;

create or replace function public.prepare_account_deletion(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  plan record;
  successor uuid;
begin
  update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
    || '{"account_deletion_pending":true}'::jsonb where id = p_user_id;
  if not found then raise exception 'Account not found'; end if;
  for plan in select id from public.travel_plans where owner_id = p_user_id for update loop
    -- A successor starting deletion must see this transferred plan in their own cleanup.
    select m.user_id into successor from public.travel_plan_members m
      join auth.users u on u.id = m.user_id
      where m.plan_id = plan.id and m.user_id <> p_user_id and m.status = 'accepted'
        and coalesce(u.raw_app_meta_data->>'account_deletion_pending', 'false') <> 'true'
      order by m.created_at, m.user_id limit 1 for update of m for share of u;
    if successor is not null then
      update public.travel_plans set owner_id = successor where id = plan.id;
      update public.travel_plan_members set invited_by = successor
        where plan_id = plan.id and invited_by = p_user_id;
      delete from public.travel_plan_members where plan_id = plan.id and user_id = successor;
    end if;
  end loop;
end;
$$;

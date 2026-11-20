-- Uses the same authenticated role as the app; all fixture changes are rolled back.
begin;
create temporary table audit_context (
  owner_id uuid, member_id uuid, plan_id uuid, day_id uuid, planned_id uuid, expense_id uuid
);
insert into audit_context(owner_id, member_id)
select min(id::text)::uuid, max(id::text)::uuid from public.profiles;
grant select, update on audit_context to authenticated;
insert into public.trip_friendships(user_low,user_high,source)
select least(owner_id,member_id),greatest(owner_id,member_id),'manual' from audit_context
on conflict do nothing;
do $$
begin
  if exists(select 1 from audit_context where owner_id is null or owner_id = member_id) then
    raise exception 'Two existing accounts are required';
  end if;
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', (select owner_id from audit_context), 'role', 'authenticated')::text, true);
end $$;
set local role authenticated;
do $$
declare
  ctx audit_context%rowtype;
  changed integer;
  new_plan uuid;
  new_day uuid;
  new_planned uuid;
begin
  select * into ctx from audit_context;
  update public.profiles set handle = 'audit_' || substr(replace(gen_random_uuid()::text,'-',''),1,16)
  where id = ctx.owner_id;
  get diagnostics changed = row_count;
  if changed <> 1 then raise exception 'Own ID update failed'; end if;
  update public.profiles set display_name = 'Forbidden' where id = ctx.member_id;
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'Another profile was editable'; end if;
  delete from public.user_follows where follower_id = ctx.owner_id and followed_id = ctx.member_id;
  insert into public.user_follows(follower_id,followed_id) values(ctx.owner_id,ctx.member_id);
  if not exists(select 1 from public.user_follows where followed_id=ctx.member_id and follower_id=ctx.owner_id)
    then raise exception 'Follow edge unavailable'; end if;
  insert into public.travel_plans(owner_id,title,region_name,start_date,end_date)
  values(ctx.owner_id,'Authenticated audit','Seoul',current_date,current_date) returning id into new_plan;
  insert into public.travel_plan_days(plan_id,travel_date,day_index)
  values(new_plan,current_date,0) returning id into new_day;
  insert into public.planned_routes(plan_day_id,title,city)
  values(new_day,'Audit route','Seoul') returning id into new_planned;
  insert into public.travel_plan_members(plan_id,user_id,invited_by,plan_title)
  values(new_plan,ctx.member_id,ctx.owner_id,'Authenticated audit');
  update audit_context set plan_id=new_plan, day_id=new_day, planned_id=new_planned;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',ctx.member_id,'role','authenticated')::text,true);
end $$;
do $$
declare
  ctx audit_context%rowtype;
  changed integer;
  new_expense uuid;
begin
  select * into ctx from audit_context;
  if exists(select 1 from public.travel_plans where id=ctx.plan_id) then
    raise exception 'Pending invite revealed private plan';
  end if;
  update public.travel_plan_members set status='accepted' where plan_id=ctx.plan_id and user_id=ctx.member_id;
  get diagnostics changed = row_count;
  if changed <> 1 then raise exception 'Invitation acceptance failed'; end if;
  if not public.can_access_travel_plan(ctx.plan_id) then raise exception 'Member access failed'; end if;
  update public.travel_plans set title='Updated by member' where id=ctx.plan_id;
  get diagnostics changed = row_count;
  if changed <> 1 then raise exception 'Member plan edit failed'; end if;
  new_expense := public.add_travel_expense(ctx.plan_id,'Lunch',10001,array[ctx.owner_id,ctx.member_id]);
  if (select sum(amount) from public.travel_expense_shares where expense_id=new_expense) <> 10001 then
    raise exception 'Expense split does not equal total';
  end if;
  update audit_context set expense_id=new_expense;

  begin
    insert into public.routes(owner_id,source_planned_route_id,title,city)
    values(ctx.member_id,ctx.planned_id,'Forbidden trip log','Seoul');
    raise exception 'Member published trip log';
  exception when raise_exception then
    if sqlerrm='Member published trip log' then raise; end if;
  end;
  insert into public.routes(owner_id,title,city) values(ctx.member_id,'Personal log','Seoul');
  perform set_config('request.jwt.claims',jsonb_build_object('sub',ctx.owner_id,'role','authenticated')::text,true);
end $$;
do $$
declare ctx audit_context%rowtype; new_log uuid;
begin
  select * into ctx from audit_context;
  if not exists(select 1 from public.travel_expenses where id=ctx.expense_id) then
    raise exception 'Owner cannot read member expenses';
  end if;
  insert into public.routes(owner_id,source_planned_route_id,title,city)
  values(ctx.owner_id,ctx.planned_id,'Owner trip log','Seoul') returning id into new_log;
  update public.travel_plan_days set completed_log_id=new_log where id=ctx.day_id;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
  if exists(select 1 from public.travel_plans where id=ctx.plan_id) or
     exists(select 1 from public.travel_expenses where id=ctx.expense_id) then
    raise exception 'Outsider read private trip data';
  end if;
end $$;
rollback;

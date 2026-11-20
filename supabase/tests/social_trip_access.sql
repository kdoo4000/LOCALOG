-- Run after the three social/trip migrations inside a transaction and ROLLBACK.
do $$
declare
  owner_id uuid;
  member_id uuid;
  v_plan_id uuid;
  day_id uuid;
  planned_id uuid;
  log_id uuid;
begin
  select id into owner_id from auth.users order by created_at limit 1;
  select id into member_id from auth.users where id <> owner_id order by created_at limit 1;
  if member_id is null then raise exception 'Two test accounts are required'; end if;
  if (select handle from public.profiles where id = owner_id) =
     (select handle from public.profiles where id = member_id) then
    raise exception 'Backfilled handles collide';
  end if;
  begin
    update public.profiles set handle = (select handle from public.profiles where id = owner_id)
    where id = member_id;
    raise exception 'Duplicate handle was accepted';
  exception when unique_violation then null;
    when raise_exception then raise;
  end;

  perform pg_catalog.set_config('request.jwt.claim.sub', owner_id::text, true);
  insert into public.travel_plans(owner_id,title,region_name,start_date,end_date)
  values(owner_id,'Invitation test','Seoul',current_date,current_date) returning id into v_plan_id;
  insert into public.travel_plan_days(plan_id,travel_date,day_index)
  values(v_plan_id,current_date,0) returning id into day_id;
  insert into public.planned_routes(plan_day_id,title,city)
  values(day_id,'Test route','Seoul') returning id into planned_id;
  insert into public.travel_plan_members(plan_id,user_id,invited_by,plan_title,status)
  values(v_plan_id,member_id,owner_id,'Invitation test','accepted');
  perform pg_catalog.set_config('request.jwt.claim.sub', member_id::text, true);
  begin
    insert into public.routes(owner_id,source_planned_route_id,title,city)
    values(member_id,planned_id,'Forbidden trip log','Seoul');
    raise exception 'Member published trip log';
  exception when raise_exception then
    if sqlerrm = 'Member published trip log' then raise; end if;
  end;
  insert into public.routes(owner_id,title,city)
  values(member_id,'Personal log','Seoul');

  perform pg_catalog.set_config('request.jwt.claim.sub', owner_id::text, true);
  insert into public.routes(owner_id,source_planned_route_id,title,city)
  values(owner_id,planned_id,'Owner trip log','Seoul') returning id into log_id;
  perform pg_catalog.set_config('request.jwt.claim.sub', member_id::text, true);
  begin
    update public.travel_plan_days set completed_log_id = log_id where id = day_id;
    raise exception 'Member attached a trip log';
  exception when raise_exception then
    if sqlerrm = 'Member attached a trip log' then raise; end if;
  end;
  perform pg_catalog.set_config('request.jwt.claim.sub', owner_id::text, true);
  update public.travel_plan_days set completed_log_id = log_id where id = day_id;
end;
$$;


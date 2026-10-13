-- Run after the three social/trip migrations inside a transaction and ROLLBACK.
do $$
declare
  owner_id uuid;
  member_id uuid;
  v_plan_id uuid;
  day_id uuid;
  planned_id uuid;
  code jsonb;
  text_code text;
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
  code := public.create_trip_invitation_code(v_plan_id);
  text_code := code->>'code';
  if length(text_code) <> 32 then raise exception 'Code is not 128 bits'; end if;
  if pg_catalog.jsonb_array_length(public.active_trip_invitation_codes(v_plan_id)) <> 1
    then raise exception 'Active invitation missing'; end if;

  perform pg_catalog.set_config('request.jwt.claim.sub', member_id::text, true);
  begin
    perform public.create_trip_invitation_code(v_plan_id);
    raise exception 'Member created an invitation';
  exception when raise_exception then
    if sqlerrm = 'Member created an invitation' then raise; end if;
  end;
  if (public.preview_trip_invitation_code(text_code)->>'title') <> 'Invitation test'
    then raise exception 'Preview title mismatch'; end if;
  if public.redeem_trip_invitation_code(text_code) <> v_plan_id
    then raise exception 'Redemption failed'; end if;
  if not exists(select 1 from public.travel_plan_members m
    where m.plan_id = v_plan_id and m.user_id = member_id and m.status = 'accepted')
    then raise exception 'Membership missing'; end if;
  perform pg_catalog.set_config('request.jwt.claim.sub', owner_id::text, true);
  if pg_catalog.jsonb_array_length(public.active_trip_invitation_codes(v_plan_id)) <> 0 then
    raise exception 'Used invitation stayed active';
  end if;
  perform pg_catalog.set_config('request.jwt.claim.sub', member_id::text, true);
  begin
    perform public.redeem_trip_invitation_code(text_code);
    raise exception 'Reused code was accepted';
  exception when raise_exception then
    if sqlerrm = 'Reused code was accepted' then raise; end if;
  end;
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
  code := public.create_trip_invitation_code(v_plan_id);
  perform public.revoke_trip_invitation_code((code->>'id')::uuid);
  perform pg_catalog.set_config('request.jwt.claim.sub', member_id::text, true);
  begin
    perform public.preview_trip_invitation_code(code->>'code');
    raise exception 'Revoked code was previewed';
  exception when raise_exception then
    if sqlerrm = 'Revoked code was previewed' then raise; end if;
  end;
  perform pg_catalog.set_config('request.jwt.claim.sub', owner_id::text, true);
  code := public.create_trip_invitation_code(v_plan_id);
  update private.trip_invitation_codes set expires_at = now() - interval '1 second'
  where id = (code->>'id')::uuid;
  perform pg_catalog.set_config('request.jwt.claim.sub', member_id::text, true);
  begin
    perform public.preview_trip_invitation_code(code->>'code');
    raise exception 'Expired code was previewed';
  exception when raise_exception then
    if sqlerrm = 'Expired code was previewed' then raise; end if;
  end;
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


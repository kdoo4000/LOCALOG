begin;
do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid();
  p uuid; n integer;
begin
  insert into auth.users(id) values(a),(b),(c);
  perform set_config('request.jwt.claim.sub',a::text,true);
  execute 'set local role authenticated';
  insert into public.travel_plans(owner_id,title,region_name,start_date,end_date)
  values(a,'Friend-only invitations','Seoul',current_date,current_date) returning id into p;
  insert into public.user_follows(follower_id,followed_id) values(a,b);
  perform public.request_trip_friend(b);
  begin
    insert into public.travel_plan_members(plan_id,user_id,invited_by,plan_title)
    values(p,b,a,'Friend-only invitations');
    raise exception 'Follow or pending friend request allowed invitation';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform public.answer_trip_friend(a,true);
  perform set_config('request.jwt.claim.sub',a::text,true);
  insert into public.travel_plan_members(plan_id,user_id,invited_by,plan_title)
  values(p,b,a,'Friend-only invitations');
  execute 'reset role';
  insert into public.trip_friendships(user_low,user_high,source) values(least(a,c),greatest(a,c),'kakao');
  execute 'set local role authenticated';
  insert into public.travel_plan_members(plan_id,user_id,invited_by,plan_title)
  values(p,c,a,'Friend-only invitations');
  perform set_config('request.jwt.claim.sub',b::text,true);
  update public.travel_plan_members set status='accepted' where plan_id=p and user_id=b;
  get diagnostics n=row_count;
  if n<>1 then raise exception 'Friend cannot accept invitation'; end if;
  execute 'reset role';
  delete from public.trip_friendships where user_low=least(a,b) and user_high=greatest(a,b);
  execute 'set local role authenticated';
  if not public.can_access_travel_plan(p) then raise exception 'Existing member lost access'; end if;
  begin
    insert into public.travel_plan_members(plan_id,user_id,invited_by,plan_title)
    values(p,a,b,'Friend-only invitations');
    raise exception 'Non-owner sent invitation';
  exception when insufficient_privilege then null; end;
  execute 'reset role';
end $$;
rollback;

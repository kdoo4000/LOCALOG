begin;
do $$
declare a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid();
ka text := 'test_'||a::text; kb text := 'test_'||b::text; n integer;
begin
  insert into auth.users(id) values(a),(b),(c);
  insert into auth.identities(user_id,provider,provider_id,identity_data)
    values(a,'kakao',ka,jsonb_build_object('sub',ka)),(b,'kakao',kb,jsonb_build_object('sub',kb));
  perform set_config('request.jwt.claim.sub',a::text,true);
  execute 'set local role authenticated';
  perform public.request_trip_friend(b);
  perform public.request_trip_friend(b);
  if (select count(*) from public.trip_friend_requests where sender_id=a and recipient_id=b) <> 1 then
    raise exception 'Duplicate request'; end if;
  begin
    insert into public.trip_friendships values(least(a,b),greatest(a,b),'manual',now());
    raise exception 'Direct friend creation accepted';
  exception when insufficient_privilege then null; end;
  begin
    perform public.sync_kakao_trip_friends(a,ka,array[kb]);
    raise exception 'Client can forge Kakao sync';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',c::text,true);
  if exists(select 1 from public.trip_friend_requests) then raise exception 'Requests leaked to stranger'; end if;
  begin
    perform public.answer_trip_friend(a,true);
    raise exception 'Stranger accepted a request';
  exception when raise_exception then
    if sqlerrm <> 'Pending request not found' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform public.answer_trip_friend(a,true);
  if not exists(select 1 from public.trip_friendships where user_low=least(a,b) and user_high=greatest(a,b)) then raise exception 'Manual friend missing'; end if;
  execute 'reset role';
  delete from public.trip_friendships where user_low=least(a,b) and user_high=greatest(a,b);
  n := public.sync_kakao_trip_friends(a,ka,array[kb]);
  if n<>0 then raise exception 'Connected friend before both consented'; end if;
  n := public.sync_kakao_trip_friends(b,kb,array[ka]);
  if n<>1 then raise exception 'Consenting Kakao friends not connected'; end if;
  n := public.sync_kakao_trip_friends(b,kb,array[ka]);
  if n<>0 then raise exception 'Duplicate Kakao friendship'; end if;
  update public.trip_friendships set source='manual' where user_low=least(a,b) and user_high=greatest(a,b);
  n := public.sync_kakao_trip_friends(b,kb,array[ka]);
  if n<>1 or not exists(select 1 from public.trip_friendships
    where user_low=least(a,b) and user_high=greatest(a,b) and source='kakao') then
    raise exception 'Verified Kakao friend remained manual'; end if;
  begin
    perform public.sync_kakao_trip_friends(c,ka,array[kb]);
    raise exception 'Mismatched account accepted';
  exception when raise_exception then
    if sqlerrm <> 'Kakao identity mismatch' then raise; end if;
  end;
  if exists(select 1 from public.user_follows where follower_id in(a,b,c)) then raise exception 'Friends changed follows'; end if;
end $$;
rollback;

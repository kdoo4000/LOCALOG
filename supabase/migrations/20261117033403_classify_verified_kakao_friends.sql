create or replace function public.sync_kakao_trip_friends(p_user uuid,p_kakao_id text,p_friend_ids text[])
returns integer language plpgsql security definer set search_path='' as $$
declare total integer;
begin
  if not exists(select 1 from auth.identities where user_id=p_user and provider='kakao' and provider_id=p_kakao_id)
    then raise exception 'Kakao identity mismatch'; end if;
  insert into public.trip_friend_consents(user_id) values(p_user)
    on conflict(user_id) do update set verified_at=now();
  insert into public.trip_friendships(user_low,user_high,source)
    select least(p_user,i.user_id),greatest(p_user,i.user_id),'kakao'
    from auth.identities i join public.trip_friend_consents c on c.user_id=i.user_id
    where i.provider='kakao' and i.provider_id=any(p_friend_ids) and i.user_id<>p_user
    on conflict(user_low,user_high) do update set source='kakao'
    where trip_friendships.source <> 'kakao';
  get diagnostics total=row_count;
  update public.trip_friend_requests r set status='accepted'
    where r.status='pending' and p_user in(r.sender_id,r.recipient_id)
    and exists(select 1 from public.trip_friendships f
      where f.user_low=least(r.sender_id,r.recipient_id) and f.user_high=greatest(r.sender_id,r.recipient_id));
  return total;
end $$;

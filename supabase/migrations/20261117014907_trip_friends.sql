create table public.trip_friendships (
  user_low uuid not null references public.profiles(id) on delete cascade,
  user_high uuid not null references public.profiles(id) on delete cascade,
  source text not null check (source in ('manual','kakao')),
  created_at timestamptz not null default now(),
  primary key(user_low,user_high), check(user_low < user_high)
);
create table public.trip_friend_requests (
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  primary key(sender_id,recipient_id), check(sender_id <> recipient_id)
);
create unique index trip_friend_pending_pair on public.trip_friend_requests
  (least(sender_id,recipient_id),greatest(sender_id,recipient_id)) where status='pending';
create table public.trip_friend_consents (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  verified_at timestamptz not null default now()
);
alter table public.trip_friendships enable row level security;
alter table public.trip_friend_requests enable row level security;
alter table public.trip_friend_consents enable row level security;
create policy trip_friends_read on public.trip_friendships for select to authenticated
  using ((select auth.uid()) in (user_low,user_high));
create policy trip_requests_read on public.trip_friend_requests for select to authenticated
  using ((select auth.uid()) in (sender_id,recipient_id));
create policy trip_consent_read on public.trip_friend_consents for select to authenticated
  using (user_id=(select auth.uid()));
grant select on public.trip_friendships,public.trip_friend_requests,public.trip_friend_consents to authenticated;
revoke insert,update,delete on public.trip_friendships,public.trip_friend_requests,public.trip_friend_consents from anon,authenticated;

create function public.request_trip_friend(p_target uuid)
returns void language plpgsql security definer set search_path='' as $$
declare me uuid := auth.uid(); lo uuid := least(me,p_target); hi uuid := greatest(me,p_target);
begin
  if me is null or p_target is null or me=p_target then raise exception 'Invalid friend request'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(lo::text||hi::text,0));
  if exists(select 1 from public.trip_friendships where user_low=lo and user_high=hi) then return; end if;
  if exists(select 1 from public.trip_friend_requests where sender_id=p_target and recipient_id=me and status='pending')
    then raise exception '먼저 받은 친구 신청에 응답해 주세요.'; end if;
  insert into public.trip_friend_requests(sender_id,recipient_id) values(me,p_target)
  on conflict(sender_id,recipient_id) do update set status='pending',created_at=now();
end $$;
create function public.answer_trip_friend(p_sender uuid,p_accept boolean)
returns void language plpgsql security definer set search_path='' as $$
declare me uuid := auth.uid(); lo uuid := least(me,p_sender); hi uuid := greatest(me,p_sender);
begin
  if me is null or p_sender is null or p_accept is null or me=p_sender then raise exception 'Invalid friend response'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(lo::text||hi::text,0));
  update public.trip_friend_requests set status=case when p_accept then 'accepted' else 'declined' end
    where sender_id=p_sender and recipient_id=me and status='pending';
  if not found then raise exception 'Pending request not found'; end if;
  if p_accept then
    insert into public.trip_friendships(user_low,user_high,source) values(lo,hi,'manual') on conflict do nothing;
  end if;
end $$;
create function public.sync_kakao_trip_friends(p_user uuid,p_kakao_id text,p_friend_ids text[])
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
    on conflict do nothing;
  get diagnostics total=row_count;
  update public.trip_friend_requests r set status='accepted'
    where r.status='pending' and p_user in(r.sender_id,r.recipient_id)
    and exists(select 1 from public.trip_friendships f
      where f.user_low=least(r.sender_id,r.recipient_id) and f.user_high=greatest(r.sender_id,r.recipient_id));
  return total;
end $$;
revoke all on function public.request_trip_friend(uuid),public.answer_trip_friend(uuid,boolean),
  public.sync_kakao_trip_friends(uuid,text,text[]) from public,anon,authenticated;
grant execute on function public.request_trip_friend(uuid),public.answer_trip_friend(uuid,boolean) to authenticated;
grant execute on function public.sync_kakao_trip_friends(uuid,text,text[]) to service_role;

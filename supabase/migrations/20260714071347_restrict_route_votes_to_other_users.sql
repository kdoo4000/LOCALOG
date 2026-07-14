delete from public.route_likes as vote
using public.routes as route
where route.id = vote.route_id
  and route.owner_id = vote.user_id;

drop policy route_likes_insert_own on public.route_likes;
drop policy route_likes_update_own on public.route_likes;

create policy route_likes_insert_own
on public.route_likes for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.routes
    where routes.id = route_likes.route_id
      and routes.access_level = 'public'
      and routes.owner_id <> (select auth.uid())
  )
);

create policy route_likes_update_own
on public.route_likes for update
to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.routes
    where routes.id = route_likes.route_id
      and routes.access_level = 'public'
      and routes.owner_id <> (select auth.uid())
  )
)
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.routes
    where routes.id = route_likes.route_id
      and routes.access_level = 'public'
      and routes.owner_id <> (select auth.uid())
  )
);

revoke update on public.route_likes from authenticated;
grant update (is_positive) on public.route_likes to authenticated;

create or replace function public.set_route_vote(
  p_route_id uuid,
  p_is_positive boolean
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_is_positive is null then
    delete from public.route_likes
    where route_id = p_route_id
      and user_id = (select auth.uid());
    return;
  end if;

  insert into public.route_likes (route_id, user_id, is_positive)
  values (p_route_id, (select auth.uid()), p_is_positive)
  on conflict (route_id, user_id) do update
  set is_positive = excluded.is_positive;
end;
$$;

revoke execute on function public.set_route_vote(uuid, boolean)
from public, anon;
grant execute on function public.set_route_vote(uuid, boolean)
to authenticated;

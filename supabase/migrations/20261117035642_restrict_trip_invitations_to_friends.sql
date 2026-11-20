create policy travel_plan_members_friends_only
on public.travel_plan_members as restrictive for insert to authenticated
with check (exists (
  select 1 from public.trip_friendships f
  where f.user_low = least((select auth.uid()), travel_plan_members.user_id)
    and f.user_high = greatest((select auth.uid()), travel_plan_members.user_id)
));

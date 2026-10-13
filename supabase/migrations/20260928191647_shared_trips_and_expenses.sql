create table public.user_follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followed_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);
create index user_follows_followed_id_idx on public.user_follows(followed_id);
alter table public.user_follows enable row level security;
revoke all on public.user_follows from anon, authenticated;
grant select, insert, delete on public.user_follows to authenticated;
create policy user_follows_read on public.user_follows for select to authenticated
using (follower_id = (select auth.uid()) or followed_id = (select auth.uid()));
create policy user_follows_insert on public.user_follows for insert to authenticated
with check (follower_id = (select auth.uid()));
create policy user_follows_delete on public.user_follows for delete to authenticated
using (follower_id = (select auth.uid()));

create table public.travel_plan_members (
  plan_id uuid not null references public.travel_plans(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  invited_by uuid not null references public.profiles(id),
  plan_title text not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  primary key (plan_id, user_id)
);
create index travel_plan_members_user_status_idx on public.travel_plan_members(user_id, status);
alter table public.travel_plan_members enable row level security;
revoke all on public.travel_plan_members from anon, authenticated;
grant select, insert, delete, update(status) on public.travel_plan_members to authenticated;

-- A single guarded membership check avoids policy recursion when plans and invitations reference each other.
create function public.can_access_travel_plan(p_plan_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and (
    exists (select 1 from public.travel_plans p where p.id = p_plan_id and p.owner_id = (select auth.uid()))
    or exists (select 1 from public.travel_plan_members m
      where m.plan_id = p_plan_id and m.user_id = (select auth.uid()) and m.status = 'accepted')
  );
$$;
revoke all on function public.can_access_travel_plan(uuid) from public, anon;
grant execute on function public.can_access_travel_plan(uuid) to authenticated;

create policy travel_plan_members_read on public.travel_plan_members for select to authenticated
using (user_id = (select auth.uid()) or public.can_access_travel_plan(plan_id));
create policy travel_plan_members_insert on public.travel_plan_members for insert to authenticated
with check (invited_by = (select auth.uid()) and user_id <> invited_by and status = 'pending'
  and exists (select 1 from public.travel_plans p where p.id = plan_id and p.owner_id = (select auth.uid())
    and p.title = plan_title));
create policy travel_plan_members_accept on public.travel_plan_members for update to authenticated
using (user_id = (select auth.uid()) and status = 'pending')
with check (user_id = (select auth.uid()) and status in ('accepted', 'declined'));
create policy travel_plan_members_remove on public.travel_plan_members for delete to authenticated
using (user_id = (select auth.uid()) or exists (
  select 1 from public.travel_plans p where p.id = plan_id and p.owner_id = (select auth.uid())
));

create policy travel_plans_member_read on public.travel_plans for select to authenticated
using (public.can_access_travel_plan(id));
create policy travel_plan_days_member_all on public.travel_plan_days for all to authenticated
using (public.can_access_travel_plan(plan_id)) with check (public.can_access_travel_plan(plan_id));
create policy planned_routes_member_all on public.planned_routes for all to authenticated
using (exists (select 1 from public.travel_plan_days d where d.id = plan_day_id and public.can_access_travel_plan(d.plan_id)))
with check (exists (select 1 from public.travel_plan_days d where d.id = plan_day_id and public.can_access_travel_plan(d.plan_id)));
create policy planned_route_places_member_all on public.planned_route_places for all to authenticated
using (exists (select 1 from public.planned_routes r join public.travel_plan_days d on d.id = r.plan_day_id
  where r.id = planned_route_id and public.can_access_travel_plan(d.plan_id)))
with check (exists (select 1 from public.planned_routes r join public.travel_plan_days d on d.id = r.plan_day_id
  where r.id = planned_route_id and public.can_access_travel_plan(d.plan_id)));
create policy travel_plan_regions_member_read on public.travel_plan_regions for select to authenticated
using (public.can_access_travel_plan(plan_id));
create policy travel_plan_regions_member_insert on public.travel_plan_regions for insert to authenticated
with check (public.can_access_travel_plan(plan_id));
create policy travel_plan_regions_member_delete on public.travel_plan_regions for delete to authenticated
using (public.can_access_travel_plan(plan_id));
create policy travel_plans_member_update on public.travel_plans for update to authenticated
using (public.can_access_travel_plan(id)) with check (public.can_access_travel_plan(id));
revoke update on public.travel_plans from authenticated;
grant update(title, region_name, start_date, end_date) on public.travel_plans to authenticated;

create table public.travel_expenses (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.travel_plans(id) on delete cascade,
  payer_id uuid not null references public.profiles(id),
  created_by uuid not null references public.profiles(id),
  title text not null check (length(btrim(title)) > 0),
  amount integer not null check (amount > 0),
  receipt_path text,
  created_at timestamptz not null default now()
);
create index travel_expenses_plan_idx on public.travel_expenses(plan_id, created_at);
alter table public.travel_expenses enable row level security;
revoke all on public.travel_expenses from anon, authenticated;
grant select, delete, update(receipt_path) on public.travel_expenses to authenticated;
create policy travel_expenses_read on public.travel_expenses for select to authenticated
using (public.can_access_travel_plan(plan_id));
create policy travel_expenses_delete on public.travel_expenses for delete to authenticated
using (created_by = (select auth.uid()));
create policy travel_expenses_photo on public.travel_expenses for update to authenticated
using (created_by = (select auth.uid()))
with check (created_by = (select auth.uid()) and (receipt_path is null or receipt_path like plan_id::text || '/' || id::text || '/%'));

create table public.travel_expense_shares (
  expense_id uuid not null references public.travel_expenses(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  amount integer not null check (amount >= 0),
  primary key (expense_id, user_id)
);
alter table public.travel_expense_shares enable row level security;
revoke all on public.travel_expense_shares from anon, authenticated;
grant select on public.travel_expense_shares to authenticated;
create policy travel_expense_shares_read on public.travel_expense_shares for select to authenticated
using (exists (select 1 from public.travel_expenses e where e.id = expense_id and public.can_access_travel_plan(e.plan_id)));

drop policy travel_plan_members_remove on public.travel_plan_members;
create policy travel_plan_members_remove on public.travel_plan_members for delete to authenticated
using ((user_id = (select auth.uid()) or exists (
    select 1 from public.travel_plans p where p.id = plan_id and p.owner_id = (select auth.uid())))
  and not exists (select 1 from public.travel_expenses e where e.plan_id = travel_plan_members.plan_id
    and (e.payer_id = travel_plan_members.user_id or exists (
      select 1 from public.travel_expense_shares s where s.expense_id = e.id
        and s.user_id = travel_plan_members.user_id))));

create function public.add_travel_expense(p_plan_id uuid, p_title text, p_amount integer, p_shared_with uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  new_id uuid;
  people uuid[];
  person uuid;
  position integer := 0;
  base_amount integer;
  remainder integer;
begin
  if not public.can_access_travel_plan(p_plan_id) then raise exception 'Plan access denied'; end if;
  if nullif(btrim(p_title), '') is null or p_amount is null or p_amount <= 0 then raise exception 'Invalid expense'; end if;
  select array_agg(distinct id order by id) into people from unnest(p_shared_with) as id;
  if coalesce(array_length(people, 1), 0) = 0 then raise exception 'Choose participants'; end if;
  if exists (select 1 from unnest(people) as id where id <> (select owner_id from public.travel_plans where id = p_plan_id)
    and not exists (select 1 from public.travel_plan_members m where m.plan_id = p_plan_id and m.user_id = id and m.status = 'accepted'))
  then raise exception 'Unknown participant'; end if;
  insert into public.travel_expenses(plan_id, payer_id, created_by, title, amount)
  values (p_plan_id, (select auth.uid()), (select auth.uid()), btrim(p_title), p_amount) returning id into new_id;
  base_amount := p_amount / array_length(people, 1);
  remainder := p_amount % array_length(people, 1);
  foreach person in array people loop
    position := position + 1;
    insert into public.travel_expense_shares(expense_id, user_id, amount)
    values (new_id, person, base_amount + case when position <= remainder then 1 else 0 end);
  end loop;
  return new_id;
end;
$$;
revoke all on function public.add_travel_expense(uuid, text, integer, uuid[]) from public, anon;
grant execute on function public.add_travel_expense(uuid, text, integer, uuid[]) to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('travel-receipts', 'travel-receipts', false, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
create policy travel_receipts_read on storage.objects for select to authenticated
using (bucket_id = 'travel-receipts' and public.can_access_travel_plan((storage.foldername(name))[1]::uuid));
create policy travel_receipts_insert on storage.objects for insert to authenticated
with check (bucket_id = 'travel-receipts' and exists (
  select 1 from public.travel_expenses e where e.id::text = (storage.foldername(name))[2]
  and e.plan_id::text = (storage.foldername(name))[1] and e.created_by = (select auth.uid())
));
create policy travel_receipts_delete on storage.objects for delete to authenticated
using (bucket_id = 'travel-receipts' and exists (
  select 1 from public.travel_expenses e where e.id::text = (storage.foldername(name))[2]
  and e.plan_id::text = (storage.foldername(name))[1]
  and (e.created_by = (select auth.uid()) or exists (
    select 1 from public.travel_plans p where p.id = e.plan_id and p.owner_id = (select auth.uid())))
));
create policy travel_receipts_update on storage.objects for update to authenticated
using (bucket_id = 'travel-receipts' and exists (
  select 1 from public.travel_expenses e where e.id::text = (storage.foldername(name))[2]
  and e.plan_id::text = (storage.foldername(name))[1] and e.created_by = (select auth.uid())
))
with check (bucket_id = 'travel-receipts' and exists (
  select 1 from public.travel_expenses e where e.id::text = (storage.foldername(name))[2]
  and e.plan_id::text = (storage.foldername(name))[1] and e.created_by = (select auth.uid())
));

create or replace function public.copy_log_route_to_plan_day(
  p_log_id uuid,
  p_plan_day_id uuid
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  source_log public.routes%rowtype;
  source_author_name text;
  copied_route_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.travel_plan_days
    join public.travel_plans
      on travel_plans.id = travel_plan_days.plan_id
    where travel_plan_days.id = p_plan_day_id
      and public.can_access_travel_plan(travel_plans.id)
  ) then
    raise exception 'Travel plan day not found';
  end if;

  select routes.*
  into source_log
  from public.routes
  where routes.id = p_log_id
    and (
      routes.access_level = 'public'
      or routes.owner_id = current_user_id
    );

  if source_log.id is null then
    raise exception 'Source log not found';
  end if;

  select display_name
  into source_author_name
  from public.profiles
  where id = source_log.owner_id;

  delete from public.planned_routes
  where plan_day_id = p_plan_day_id;

  insert into public.planned_routes (
    plan_day_id,
    source_log_id,
    source_log_title,
    source_author_name,
    title,
    city,
    estimated_duration_minutes
  ) values (
    p_plan_day_id,
    source_log.id,
    source_log.title,
    coalesce(source_author_name, 'LOCALOG 여행자'),
    source_log.title,
    source_log.city,
    source_log.estimated_duration_minutes
  )
  returning id into copied_route_id;

  insert into public.planned_route_places (
    planned_route_id,
    place_id,
    name,
    category,
    order_index,
    address,
    latitude,
    longitude
  )
  select
    copied_route_id,
    route_places.place_id,
    route_places.name,
    route_places.category,
    route_places.order_index,
    route_places.address,
    route_places.latitude,
    route_places.longitude
  from public.route_places
  where route_places.route_id = source_log.id
  order by route_places.order_index;

  insert into public.route_downloads (route_id, user_id)
  values (source_log.id, current_user_id)
  on conflict (route_id, user_id) do nothing;

  return copied_route_id;
end;
$$;

revoke execute on function public.copy_log_route_to_plan_day(uuid, uuid)
from public, anon;
grant execute on function public.copy_log_route_to_plan_day(uuid, uuid)
to authenticated;


create or replace function public.update_travel_plan(
  p_plan_id uuid,
  p_title text,
  p_regions text[],
  p_start_date date,
  p_end_date date
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  normalized_regions text[];
  new_day_count integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  if nullif(pg_catalog.btrim(p_title), '') is null then
    raise exception 'Title is required';
  end if;

  if p_start_date is null
    or p_end_date is null
    or p_end_date < p_start_date
    or p_end_date - p_start_date > 30 then
    raise exception 'Travel dates must span between 1 and 31 days';
  end if;

  select coalesce(
    pg_catalog.array_agg(region_name order by first_order),
    array[]::text[]
  )
  into normalized_regions
  from (
    select
      pg_catalog.btrim(region) as region_name,
      pg_catalog.min(region_order) as first_order
    from pg_catalog.unnest(p_regions) with ordinality
      as input_regions(region, region_order)
    where nullif(pg_catalog.btrim(region), '') is not null
    group by pg_catalog.btrim(region)
  ) as distinct_regions;

  if pg_catalog.cardinality(normalized_regions) = 0 then
    raise exception 'At least one region is required';
  end if;

  perform 1
  from public.travel_plans
  where id = p_plan_id
    and public.can_access_travel_plan(id)
  for update;

  if not found then
    raise exception 'Travel plan not found';
  end if;

  update public.travel_plans
  set title = pg_catalog.btrim(p_title),
      region_name = normalized_regions[1],
      start_date = p_start_date,
      end_date = p_end_date
  where id = p_plan_id;

  delete from public.travel_plan_regions
  where plan_id = p_plan_id;

  insert into public.travel_plan_regions (plan_id, region_name, order_index)
  select p_plan_id, region_name, region_order - 1
  from pg_catalog.unnest(normalized_regions) with ordinality
    as regions(region_name, region_order);

  new_day_count := p_end_date - p_start_date + 1;

  update public.travel_plan_days
  set travel_date = date '0001-01-01' + day_index
  where plan_id = p_plan_id;

  delete from public.travel_plan_days
  where plan_id = p_plan_id
    and day_index >= new_day_count;

  update public.travel_plan_days
  set travel_date = p_start_date + day_index
  where plan_id = p_plan_id;

  insert into public.travel_plan_days (plan_id, travel_date, day_index)
  select p_plan_id, p_start_date + day_index, day_index
  from pg_catalog.generate_series(0, new_day_count - 1)
    as new_days(day_index)
  where not exists (
    select 1
    from public.travel_plan_days
    where travel_plan_days.plan_id = p_plan_id
      and travel_plan_days.day_index = new_days.day_index
  );
end;
$$;

revoke all on function public.update_travel_plan(uuid, text, text[], date, date)
from public, anon;

grant execute on function public.update_travel_plan(uuid, text, text[], date, date)
to authenticated;

create or replace function private.validate_completed_plan_log()
returns trigger language plpgsql set search_path = '' as $$
declare
  plan_owner_id uuid;
  planned_route_id uuid;
begin
  if new.completed_log_id is null then return new; end if;
  select p.owner_id, r.id into plan_owner_id, planned_route_id
  from public.travel_plans p join public.planned_routes r on r.plan_day_id = new.id
  where p.id = new.plan_id;
  if planned_route_id is null then raise exception 'A completed log requires a planned route'; end if;
  if not exists (
    select 1 from public.routes log
    where log.id = new.completed_log_id
      and log.source_planned_route_id = planned_route_id
      and (log.owner_id = plan_owner_id or exists (
        select 1 from public.travel_plan_members m where m.plan_id = new.plan_id
          and m.user_id = log.owner_id and m.status = 'accepted'))
  ) then raise exception 'Completed log must belong to a trip participant'; end if;
  return new;
end;
$$;


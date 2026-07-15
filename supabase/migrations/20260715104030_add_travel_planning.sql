create table public.travel_plans (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  region_name text not null,
  start_date date not null,
  end_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint travel_plans_title_not_blank
    check (length(btrim(title)) > 0),
  constraint travel_plans_region_not_blank
    check (length(btrim(region_name)) > 0),
  constraint travel_plans_date_range_valid
    check (end_date >= start_date),
  constraint travel_plans_duration_valid
    check (end_date - start_date <= 30)
);

create table public.travel_plan_days (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.travel_plans(id) on delete cascade,
  travel_date date not null,
  day_index integer not null,
  completed_log_id uuid references public.routes(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint travel_plan_days_index_valid check (day_index >= 0),
  unique (plan_id, travel_date),
  unique (plan_id, day_index)
);

create table public.planned_routes (
  id uuid primary key default gen_random_uuid(),
  plan_day_id uuid not null unique
    references public.travel_plan_days(id) on delete cascade,
  source_log_id uuid references public.routes(id) on delete set null,
  source_log_title text,
  source_author_name text,
  title text not null,
  city text not null,
  estimated_duration_minutes integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint planned_routes_title_not_blank check (length(btrim(title)) > 0),
  constraint planned_routes_city_not_blank check (length(btrim(city)) > 0),
  constraint planned_routes_duration_valid
    check (estimated_duration_minutes >= 0)
);

create table public.planned_route_places (
  id uuid primary key default gen_random_uuid(),
  planned_route_id uuid not null
    references public.planned_routes(id) on delete cascade,
  place_id uuid references public.places(id) on delete set null,
  name text not null,
  category text not null,
  order_index integer not null,
  address text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint planned_route_places_name_not_blank
    check (length(btrim(name)) > 0),
  constraint planned_route_places_category_not_blank
    check (length(btrim(category)) > 0),
  constraint planned_route_places_order_valid check (order_index >= 0),
  constraint planned_route_places_location_pair check (
    (latitude is null and longitude is null)
    or (
      latitude between -90 and 90
      and longitude between -180 and 180
    )
  ),
  unique (planned_route_id, order_index)
);

alter table public.routes
add column travel_date date,
add column source_planned_route_id uuid
  references public.planned_routes(id) on delete set null;

create index travel_plans_owner_start_date_idx
on public.travel_plans(owner_id, start_date);

create index travel_plan_days_plan_id_idx
on public.travel_plan_days(plan_id);

create index travel_plan_days_completed_log_id_idx
on public.travel_plan_days(completed_log_id)
where completed_log_id is not null;

create index routes_source_planned_route_id_idx
on public.routes(source_planned_route_id)
where source_planned_route_id is not null;

create index planned_routes_source_log_id_idx
on public.planned_routes(source_log_id)
where source_log_id is not null;

create index planned_route_places_planned_route_id_idx
on public.planned_route_places(planned_route_id);

create index planned_route_places_place_id_idx
on public.planned_route_places(place_id)
where place_id is not null;

create trigger travel_plans_set_updated_at
before update on public.travel_plans
for each row execute function private.set_updated_at();

create trigger planned_routes_set_updated_at
before update on public.planned_routes
for each row execute function private.set_updated_at();

create trigger planned_route_places_set_updated_at
before update on public.planned_route_places
for each row execute function private.set_updated_at();

alter table public.travel_plans enable row level security;
alter table public.travel_plan_days enable row level security;
alter table public.planned_routes enable row level security;
alter table public.planned_route_places enable row level security;

create policy travel_plans_owner_all
on public.travel_plans for all
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

create policy travel_plan_days_owner_all
on public.travel_plan_days for all
to authenticated
using (
  exists (
    select 1 from public.travel_plans
    where travel_plans.id = travel_plan_days.plan_id
      and travel_plans.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.travel_plans
    where travel_plans.id = travel_plan_days.plan_id
      and travel_plans.owner_id = (select auth.uid())
  )
);

create policy planned_routes_owner_all
on public.planned_routes for all
to authenticated
using (
  exists (
    select 1
    from public.travel_plan_days
    join public.travel_plans
      on travel_plans.id = travel_plan_days.plan_id
    where travel_plan_days.id = planned_routes.plan_day_id
      and travel_plans.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.travel_plan_days
    join public.travel_plans
      on travel_plans.id = travel_plan_days.plan_id
    where travel_plan_days.id = planned_routes.plan_day_id
      and travel_plans.owner_id = (select auth.uid())
  )
);

create policy planned_route_places_owner_all
on public.planned_route_places for all
to authenticated
using (
  exists (
    select 1
    from public.planned_routes
    join public.travel_plan_days
      on travel_plan_days.id = planned_routes.plan_day_id
    join public.travel_plans
      on travel_plans.id = travel_plan_days.plan_id
    where planned_routes.id = planned_route_places.planned_route_id
      and travel_plans.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.planned_routes
    join public.travel_plan_days
      on travel_plan_days.id = planned_routes.plan_day_id
    join public.travel_plans
      on travel_plans.id = travel_plan_days.plan_id
    where planned_routes.id = planned_route_places.planned_route_id
      and travel_plans.owner_id = (select auth.uid())
  )
);

grant select, insert, update, delete on public.travel_plans to authenticated;
grant select, insert, update, delete on public.travel_plan_days to authenticated;
grant select, insert, update, delete on public.planned_routes to authenticated;
grant select, insert, update, delete on public.planned_route_places
to authenticated;

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
      and travel_plans.owner_id = current_user_id
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

create or replace function public.save_planned_route(
  p_planned_route_id uuid,
  p_title text,
  p_city text,
  p_estimated_duration_minutes integer,
  p_places jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  place_value jsonb;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if nullif(pg_catalog.btrim(p_title), '') is null then
    raise exception 'A planned route requires a title';
  end if;
  if nullif(pg_catalog.btrim(p_city), '') is null then
    raise exception 'A planned route requires a city';
  end if;
  if p_estimated_duration_minutes < 0 then
    raise exception 'Duration cannot be negative';
  end if;

  update public.planned_routes
  set title = pg_catalog.btrim(p_title),
      city = pg_catalog.btrim(p_city),
      estimated_duration_minutes = p_estimated_duration_minutes
  where id = p_planned_route_id;

  if not found then
    raise exception 'Planned route not found';
  end if;

  delete from public.planned_route_places
  where planned_route_id = p_planned_route_id;

  for place_value in
    select value from jsonb_array_elements(coalesce(p_places, '[]'::jsonb))
  loop
    insert into public.planned_route_places (
      planned_route_id,
      place_id,
      name,
      category,
      order_index,
      address,
      latitude,
      longitude
    ) values (
      p_planned_route_id,
      nullif(place_value ->> 'place_id', '')::uuid,
      pg_catalog.btrim(place_value ->> 'name'),
      pg_catalog.btrim(place_value ->> 'category'),
      (place_value ->> 'order_index')::integer,
      nullif(pg_catalog.btrim(place_value ->> 'address'), ''),
      nullif(place_value ->> 'latitude', '')::double precision,
      nullif(place_value ->> 'longitude', '')::double precision
    );
  end loop;
end;
$$;

revoke execute on function public.save_planned_route(
  uuid, text, text, integer, jsonb
) from public, anon;
grant execute on function public.save_planned_route(
  uuid, text, text, integer, jsonb
) to authenticated;

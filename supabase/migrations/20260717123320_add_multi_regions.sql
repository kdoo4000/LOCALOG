create table public.route_regions (
  route_id uuid not null references public.routes(id) on delete cascade,
  region_name text not null,
  order_index integer not null,
  created_at timestamptz not null default now(),
  primary key (route_id, region_name),
  unique (route_id, order_index),
  constraint route_regions_name_not_blank
    check (length(pg_catalog.btrim(region_name)) > 0),
  constraint route_regions_order_valid check (order_index >= 0)
);

create table public.travel_plan_regions (
  plan_id uuid not null references public.travel_plans(id) on delete cascade,
  region_name text not null,
  order_index integer not null,
  created_at timestamptz not null default now(),
  primary key (plan_id, region_name),
  unique (plan_id, order_index),
  constraint travel_plan_regions_name_not_blank
    check (length(pg_catalog.btrim(region_name)) > 0),
  constraint travel_plan_regions_order_valid check (order_index >= 0)
);

create index route_regions_region_name_idx
on public.route_regions(region_name);

create index travel_plan_regions_region_name_idx
on public.travel_plan_regions(region_name);

insert into public.route_regions (route_id, region_name, order_index)
select id, pg_catalog.btrim(city), 0
from public.routes
where nullif(pg_catalog.btrim(city), '') is not null;

insert into public.travel_plan_regions (plan_id, region_name, order_index)
select id, pg_catalog.btrim(region_name), 0
from public.travel_plans
where nullif(pg_catalog.btrim(region_name), '') is not null;

alter table public.route_regions enable row level security;
alter table public.travel_plan_regions enable row level security;

create policy route_regions_public_or_owner_read
on public.route_regions for select
to anon, authenticated
using (
  exists (
    select 1
    from public.routes
    where routes.id = route_regions.route_id
      and (
        routes.access_level = 'public'
        or routes.owner_id = (select auth.uid())
      )
  )
);

create policy route_regions_owner_insert
on public.route_regions for insert
to authenticated
with check (
  exists (
    select 1
    from public.routes
    where routes.id = route_regions.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_regions_owner_delete
on public.route_regions for delete
to authenticated
using (
  exists (
    select 1
    from public.routes
    where routes.id = route_regions.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy travel_plan_regions_owner_read
on public.travel_plan_regions for select
to authenticated
using (
  exists (
    select 1
    from public.travel_plans
    where travel_plans.id = travel_plan_regions.plan_id
      and travel_plans.owner_id = (select auth.uid())
  )
);

create policy travel_plan_regions_owner_insert
on public.travel_plan_regions for insert
to authenticated
with check (
  exists (
    select 1
    from public.travel_plans
    where travel_plans.id = travel_plan_regions.plan_id
      and travel_plans.owner_id = (select auth.uid())
  )
);

create policy travel_plan_regions_owner_delete
on public.travel_plan_regions for delete
to authenticated
using (
  exists (
    select 1
    from public.travel_plans
    where travel_plans.id = travel_plan_regions.plan_id
      and travel_plans.owner_id = (select auth.uid())
  )
);

grant select on public.route_regions to anon, authenticated;
grant insert, delete on public.route_regions to authenticated;
grant select, insert, delete on public.travel_plan_regions to authenticated;

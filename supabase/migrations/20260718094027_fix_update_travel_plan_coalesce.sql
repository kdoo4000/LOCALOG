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
    and owner_id = (select auth.uid())
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

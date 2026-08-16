create table private.naver_proxy_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  request_count integer not null,
  constraint naver_proxy_rate_limits_request_count_valid check (request_count > 0)
);

alter table private.naver_proxy_rate_limits enable row level security;
revoke all on private.naver_proxy_rate_limits from public, anon, authenticated;

create or replace function public.consume_naver_proxy_quota()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  current_time timestamptz := pg_catalog.clock_timestamp();
  allowed boolean;
begin
  if current_user_id is null then return false; end if;

  insert into private.naver_proxy_rate_limits (
    user_id, window_started_at, request_count
  ) values (current_user_id, current_time, 1)
  on conflict (user_id) do update
  set window_started_at = case
        when private.naver_proxy_rate_limits.window_started_at <= current_time - interval '1 minute'
          then current_time
        else private.naver_proxy_rate_limits.window_started_at
      end,
      request_count = case
        when private.naver_proxy_rate_limits.window_started_at <= current_time - interval '1 minute'
          then 1
        else private.naver_proxy_rate_limits.request_count + 1
      end
  where private.naver_proxy_rate_limits.window_started_at <= current_time - interval '1 minute'
     or private.naver_proxy_rate_limits.request_count < 60
  returning true into allowed;

  return coalesce(allowed, false);
end;
$$;

revoke execute on function public.consume_naver_proxy_quota() from public, anon;
grant execute on function public.consume_naver_proxy_quota() to authenticated;

create or replace function public.save_route_revision_with_regions(
  p_route_id uuid,
  p_title text,
  p_description text,
  p_city text,
  p_access_level text,
  p_estimated_duration_minutes integer,
  p_tags text[],
  p_places jsonb,
  p_photos jsonb,
  p_cover_image_path text,
  p_regions text[]
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  normalized_regions text[];
  result jsonb;
begin
  select pg_catalog.array_agg(region order by first_ordinal)
  into normalized_regions
  from (
    select pg_catalog.btrim(value) as region, min(ordinal) as first_ordinal
    from pg_catalog.unnest(coalesce(p_regions, array[]::text[]))
      with ordinality as requested(value, ordinal)
    where pg_catalog.btrim(value) <> ''
    group by pg_catalog.btrim(value)
  ) as normalized;

  if coalesce(pg_catalog.array_length(normalized_regions, 1), 0) = 0 then
    raise exception 'A route requires at least one region';
  end if;

  result := public.save_route_revision(
    p_route_id, p_title, p_description, p_city, p_access_level,
    p_estimated_duration_minutes, p_tags, p_places, p_photos,
    p_cover_image_path
  );

  delete from public.route_regions where route_id = p_route_id;
  insert into public.route_regions (route_id, region_name, order_index)
  select p_route_id, region, ordinal - 1
  from pg_catalog.unnest(normalized_regions) with ordinality
    as regions(region, ordinal);

  return result;
end;
$$;

revoke execute on function public.save_route_revision_with_regions(
  uuid, text, text, text, text, integer, text[], jsonb, jsonb, text, text[]
) from public, anon;
grant execute on function public.save_route_revision_with_regions(
  uuid, text, text, text, text, integer, text[], jsonb, jsonb, text, text[]
) to authenticated;

create or replace function public.create_travel_plan(
  p_title text,
  p_regions text[],
  p_start_date date,
  p_end_date date
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  normalized_regions text[];
  created_plan_id uuid;
  day_offset integer;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if nullif(pg_catalog.btrim(p_title), '') is null then
    raise exception 'A travel plan requires a title';
  end if;
  if p_start_date is null or p_end_date is null or p_end_date < p_start_date then
    raise exception 'Invalid travel date range';
  end if;
  if p_end_date - p_start_date > 30 then
    raise exception 'Travel plan cannot exceed 31 days';
  end if;

  select pg_catalog.array_agg(region order by first_ordinal)
  into normalized_regions
  from (
    select pg_catalog.btrim(value) as region, min(ordinal) as first_ordinal
    from pg_catalog.unnest(coalesce(p_regions, array[]::text[]))
      with ordinality as requested(value, ordinal)
    where pg_catalog.btrim(value) <> ''
    group by pg_catalog.btrim(value)
  ) as normalized;

  if coalesce(pg_catalog.array_length(normalized_regions, 1), 0) = 0 then
    raise exception 'A travel plan requires at least one region';
  end if;

  insert into public.travel_plans (
    owner_id, title, region_name, start_date, end_date
  ) values (
    current_user_id, pg_catalog.btrim(p_title), normalized_regions[1],
    p_start_date, p_end_date
  ) returning id into created_plan_id;

  insert into public.travel_plan_regions (plan_id, region_name, order_index)
  select created_plan_id, region, ordinal - 1
  from pg_catalog.unnest(normalized_regions) with ordinality
    as regions(region, ordinal);

  for day_offset in 0..(p_end_date - p_start_date) loop
    insert into public.travel_plan_days (plan_id, travel_date, day_index)
    values (created_plan_id, p_start_date + day_offset, day_offset);
  end loop;

  return created_plan_id;
end;
$$;

revoke execute on function public.create_travel_plan(text, text[], date, date)
from public, anon;
grant execute on function public.create_travel_plan(text, text[], date, date)
to authenticated;

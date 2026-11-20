alter table public.travel_plan_days add column accommodation jsonb;
alter table public.travel_plan_days add constraint accommodation_valid check (
  accommodation is null or (
    jsonb_typeof(accommodation) = 'object'
    and jsonb_typeof(accommodation->'name') = 'string'
    and coalesce(length(btrim(accommodation->>'name')),0) between 1 and 200
    and (accommodation->>'id' is null or jsonb_typeof(accommodation->'id') = 'string')
    and (accommodation->>'source' is null or jsonb_typeof(accommodation->'source') = 'string')
    and (accommodation->>'address' is null or jsonb_typeof(accommodation->'address') = 'string')
    and (accommodation->>'category' is null or jsonb_typeof(accommodation->'category') = 'string')
    and (accommodation->>'sourceCategory' is null or jsonb_typeof(accommodation->'sourceCategory') = 'string')
    and (accommodation->>'latitude' is null or jsonb_typeof(accommodation->'latitude') = 'number')
    and (accommodation->>'longitude' is null or jsonb_typeof(accommodation->'longitude') = 'number')
    and pg_column_size(accommodation) <= 8192
    and (accommodation->>'latitude' is null or
      (accommodation->>'latitude')::double precision between -90 and 90)
    and (accommodation->>'longitude' is null or
      (accommodation->>'longitude')::double precision between -180 and 180)
  )
);
alter table public.planned_route_places add column accommodation_role text
  check (accommodation_role in ('start', 'end'));

-- This only replaces automatically added stops; ordinary places keep their IDs.
create function public.sync_plan_day_accommodation(p_plan_day_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  day_record record;
  previous_stay jsonb;
  current_stay jsonb;
  route_id uuid;
  offset_index integer;
  place_count integer;
  start_count integer;
  stay jsonb;
  boundary text;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select d.*, p.end_date, p.region_name into day_record
  from public.travel_plan_days d join public.travel_plans p on p.id = d.plan_id
  where d.id = p_plan_day_id for update of d;
  if not found then return; end if;

  select accommodation into previous_stay from public.travel_plan_days
  where plan_id = day_record.plan_id and day_index = day_record.day_index - 1;
  current_stay := day_record.accommodation;
  if day_record.travel_date >= day_record.end_date then
    current_stay := null;
    update public.travel_plan_days set accommodation = null
    where id = p_plan_day_id and accommodation is not null;
  end if;
  select id into route_id from public.planned_routes where plan_day_id = p_plan_day_id;
  if previous_stay is null and current_stay is null and not exists (
    select 1 from public.planned_route_places
    where planned_route_id = route_id and accommodation_role is not null
  ) then return; end if;
  if route_id is null then
    if previous_stay is null and current_stay is null then return; end if;
    insert into public.planned_routes(plan_day_id,title,city,estimated_duration_minutes)
    values (p_plan_day_id, 'DAY ' || (day_record.day_index + 1) || ' 여행 루트', day_record.region_name, 0)
    returning id into route_id;
  end if;

  delete from public.planned_route_places
  where planned_route_id = route_id and accommodation_role is not null;
  select count(*)::integer, coalesce(max(order_index),0) + count(*)::integer + 1
    into place_count, offset_index
  from public.planned_route_places where planned_route_id = route_id;
  start_count := case when previous_stay is null then 0 else 1 end;
  update public.planned_route_places set order_index = order_index + offset_index
  where planned_route_id = route_id;
  with ranked as (
    select id, row_number() over(order by order_index)::integer - 1 + start_count as position
    from public.planned_route_places where planned_route_id = route_id
  ) update public.planned_route_places p set order_index = ranked.position
    from ranked where p.id = ranked.id;

  foreach boundary in array array['start','end'] loop
    stay := case when boundary = 'start' then previous_stay else current_stay end;
    if stay is not null then
      insert into public.planned_route_places(
        planned_route_id,name,category,source_category,order_index,address,latitude,longitude,accommodation_role
      ) values (
        route_id,btrim(stay->>'name'),coalesce(nullif(stay->>'category',''),'숙소'),
        stay->>'sourceCategory',case when boundary = 'start' then 0 else place_count + start_count end,
        nullif(stay->>'address',''),(stay->>'latitude')::double precision,
        (stay->>'longitude')::double precision,boundary
      );
    end if;
  end loop;
end;
$$;

create function public.sync_changed_day_accommodation()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare next_day_id uuid;
begin
  perform public.sync_plan_day_accommodation(new.id);
  select following.id into next_day_id
  from public.travel_plan_days current_day join public.travel_plan_days following
    on following.plan_id = current_day.plan_id and following.day_index = current_day.day_index + 1
  where current_day.id = new.id;
  if next_day_id is not null then perform public.sync_plan_day_accommodation(next_day_id); end if;
  return null;
end;
$$;

create constraint trigger travel_plan_day_accommodation_sync
after update on public.travel_plan_days deferrable initially deferred for each row
when (old.accommodation is distinct from new.accommodation
  or old.day_index is distinct from new.day_index or old.travel_date is distinct from new.travel_date)
execute function public.sync_changed_day_accommodation();

create function public.sync_changed_route_accommodation()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if exists(select 1 from public.planned_routes where id = new.id) then
    perform public.sync_plan_day_accommodation(new.plan_day_id);
  end if;
  return null;
end;
$$;

-- Deferred until all copied or edited places have been written atomically.
create constraint trigger planned_route_accommodation_sync
after insert or update on public.planned_routes deferrable initially deferred for each row
execute function public.sync_changed_route_accommodation();

create function public.set_plan_day_accommodation(p_plan_day_id uuid, p_accommodation jsonb)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare plan_id_value uuid;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select p.id into plan_id_value from public.travel_plans p
  join public.travel_plan_days d on d.plan_id = p.id
  where d.id = p_plan_day_id and d.travel_date < p.end_date for update of p;
  if not found then raise exception 'A night within your travel plan is required'; end if;
  update public.travel_plan_days set accommodation = p_accommodation where id = p_plan_day_id;
  return plan_id_value;
end;
$$;

create function public.create_planned_route(
  p_plan_day_id uuid,p_title text,p_city text,p_estimated_duration_minutes integer,p_places jsonb
)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare route_id uuid;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(p_places) is distinct from 'array' or jsonb_array_length(p_places) = 0 then
    raise exception 'At least one place is required';
  end if;
  insert into public.planned_routes(plan_day_id,title,city,estimated_duration_minutes)
  values(p_plan_day_id,btrim(p_title),btrim(p_city),p_estimated_duration_minutes)
  on conflict(plan_day_id) do update set
    title = excluded.title, city = excluded.city,
    estimated_duration_minutes = excluded.estimated_duration_minutes,
    source_log_id = null,source_log_title = null,source_author_name = null
  returning id into route_id;
  perform public.save_planned_route(route_id,p_title,p_city,p_estimated_duration_minutes,p_places);
  return route_id;
end;
$$;

revoke execute on function public.sync_plan_day_accommodation(uuid) from public,anon;
grant execute on function public.sync_plan_day_accommodation(uuid) to authenticated;
revoke execute on function public.sync_changed_day_accommodation() from public,anon;
revoke execute on function public.sync_changed_route_accommodation() from public,anon;
revoke execute on function public.set_plan_day_accommodation(uuid,jsonb) from public,anon;
grant execute on function public.set_plan_day_accommodation(uuid,jsonb) to authenticated;
revoke execute on function public.create_planned_route(uuid,text,text,integer,jsonb) from public,anon;
grant execute on function public.create_planned_route(uuid,text,text,integer,jsonb) to authenticated;

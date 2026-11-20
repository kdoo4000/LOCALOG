create function private.validate_trip_log_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.source_planned_route_id is not null and not exists (
    select 1 from public.planned_routes r
    join public.travel_plan_days d on d.id = r.plan_day_id
    join public.travel_plans p on p.id = d.plan_id
    where r.id = new.source_planned_route_id
      and p.owner_id = (select auth.uid())
      and new.owner_id = p.owner_id
  ) then raise exception 'Only the trip owner can publish a trip log'; end if;
  return new;
end;
$$;
revoke all on function private.validate_trip_log_owner() from public, anon, authenticated;
create trigger routes_validate_trip_log_owner
before insert or update of source_planned_route_id, owner_id on public.routes
for each row execute function private.validate_trip_log_owner();

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
  if plan_owner_id <> (select auth.uid()) then
    raise exception 'Only the trip owner can attach a completed log';
  end if;
  if planned_route_id is null then raise exception 'A completed log requires a planned route'; end if;
  if not exists (
    select 1 from public.routes log
    where log.id = new.completed_log_id
      and log.source_planned_route_id = planned_route_id
      and log.owner_id = plan_owner_id
  ) then raise exception 'Completed log must belong to the trip owner'; end if;
  return new;
end;
$$;

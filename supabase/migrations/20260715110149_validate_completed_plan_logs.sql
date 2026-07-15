create or replace function private.validate_completed_plan_log()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  plan_owner_id uuid;
  planned_route_id uuid;
begin
  if new.completed_log_id is null then
    return new;
  end if;

  select travel_plans.owner_id, planned_routes.id
  into plan_owner_id, planned_route_id
  from public.travel_plans
  join public.planned_routes
    on planned_routes.plan_day_id = new.id
  where travel_plans.id = new.plan_id;

  if planned_route_id is null then
    raise exception 'A completed log requires a planned route';
  end if;

  if not exists (
    select 1
    from public.routes
    where routes.id = new.completed_log_id
      and routes.owner_id = plan_owner_id
      and routes.source_planned_route_id = planned_route_id
  ) then
    raise exception 'Completed log must belong to this planned route owner';
  end if;

  return new;
end;
$$;

revoke execute on function private.validate_completed_plan_log()
from public, anon, authenticated;

create trigger travel_plan_days_validate_completed_log
before insert or update of completed_log_id
on public.travel_plan_days
for each row execute function private.validate_completed_plan_log();

alter table public.places
add column source_category text;

alter table public.route_places
add column source_category text;

alter table public.planned_route_places
add column source_category text;

create or replace function private.normalize_place_category()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.category := nullif(pg_catalog.btrim(new.category), '');
  new.source_category := nullif(pg_catalog.btrim(new.source_category), '');

  if new.category is not null and pg_catalog.strpos(new.category, '>') > 0 then
    new.source_category := coalesce(new.source_category, new.category);
    new.category := nullif(
      pg_catalog.btrim(
        pg_catalog.regexp_replace(
          new.category,
          '^.*>[[:space:]]*',
          ''
        )
      ),
      ''
    );
  end if;

  return new;
end;
$$;

revoke execute on function private.normalize_place_category()
from public, anon, authenticated;

create trigger places_normalize_category
before insert or update of category, source_category
on public.places
for each row execute function private.normalize_place_category();

create trigger route_places_normalize_category
before insert or update of category, source_category
on public.route_places
for each row execute function private.normalize_place_category();

create trigger planned_route_places_normalize_category
before insert or update of category, source_category
on public.planned_route_places
for each row execute function private.normalize_place_category();

update public.places
set category = category
where pg_catalog.strpos(category, '>') > 0;

update public.route_places
set category = category
where pg_catalog.strpos(category, '>') > 0;

update public.planned_route_places
set category = category
where pg_catalog.strpos(category, '>') > 0;

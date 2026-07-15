create table public.places (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  category text,
  normalized_name text not null,
  normalized_address text not null,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  constraint places_name_not_blank check (length(btrim(name)) > 0),
  constraint places_address_not_blank check (length(btrim(address)) > 0),
  constraint places_normalized_name_not_blank check (
    length(normalized_name) > 0
  ),
  constraint places_normalized_address_not_blank check (
    length(normalized_address) > 0
  ),
  constraint places_location_pair check (
    (latitude is null and longitude is null)
    or (
      latitude between -90 and 90
      and longitude between -180 and 180
    )
  ),
  unique (normalized_name, normalized_address)
);

create or replace function private.normalize_place_identity(value text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select pg_catalog.lower(
    pg_catalog.regexp_replace(
      pg_catalog.btrim(value),
      '[[:space:]]+',
      '',
      'g'
    )
  )
$$;

create or replace function private.set_place_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.name := pg_catalog.btrim(new.name);
  new.address := pg_catalog.btrim(new.address);
  new.category := nullif(pg_catalog.btrim(new.category), '');
  new.normalized_name := pg_catalog.lower(
    pg_catalog.regexp_replace(new.name, '[[:space:]]+', '', 'g')
  );
  new.normalized_address := pg_catalog.lower(
    pg_catalog.regexp_replace(new.address, '[[:space:]]+', '', 'g')
  );
  return new;
end;
$$;

revoke execute on function private.normalize_place_identity(text)
from public, anon, authenticated;
revoke execute on function private.set_place_identity()
from public, anon, authenticated;

create trigger places_set_identity
before insert or update of name, address on public.places
for each row execute function private.set_place_identity();

alter table public.route_places
add column place_id uuid references public.places(id) on delete restrict;

insert into public.places (
  name,
  address,
  category,
  normalized_name,
  normalized_address
)
select
  source.name,
  source.address,
  source.category,
  source.normalized_name,
  source.normalized_address
from (
  select distinct on (
    private.normalize_place_identity(name),
    private.normalize_place_identity(address)
  )
    name,
    address,
    category,
    private.normalize_place_identity(name) as normalized_name,
    private.normalize_place_identity(address) as normalized_address
  from public.route_places
  where nullif(btrim(name), '') is not null
    and nullif(btrim(address), '') is not null
  order by
    private.normalize_place_identity(name),
    private.normalize_place_identity(address),
    created_at,
    id
) as source
on conflict (normalized_name, normalized_address) do nothing;

update public.route_places as route_place
set place_id = place.id
from public.places as place
where place.normalized_name =
      private.normalize_place_identity(route_place.name)
  and place.normalized_address =
      private.normalize_place_identity(route_place.address)
  and nullif(btrim(route_place.address), '') is not null;

do $$
begin
  if exists (
    select 1
    from public.route_places
    where place_id is null
  ) then
    raise exception 'Every existing route place must have a non-blank address';
  end if;
end;
$$;

alter table public.route_places
alter column place_id set not null;

create index route_places_place_id_idx
on public.route_places(place_id);

alter table public.places enable row level security;

create policy places_public_read
on public.places for select
to anon, authenticated
using (true);

create policy places_authenticated_insert
on public.places for insert
to authenticated
with check (true);

grant select on public.places to anon, authenticated;
grant insert (name, address, category, latitude, longitude)
on public.places to authenticated;

create or replace function public.save_route_revision(
  p_route_id uuid,
  p_title text,
  p_description text,
  p_city text,
  p_access_level text,
  p_estimated_duration_minutes integer,
  p_tags text[],
  p_places jsonb,
  p_photos jsonb,
  p_cover_image_path text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_owner_id uuid;
  place_value jsonb;
  photo_value jsonb;
  place_client_key text;
  place_id_value uuid;
  canonical_place_id_value uuid;
  requested_canonical_place_id uuid;
  normalized_place_name text;
  normalized_place_address text;
  existing_place_id uuid;
  place_ids uuid[] := array[]::uuid[];
  keep_photo_paths text[] := array[]::text[];
  removed_storage_paths text[] := array[]::text[];
  place_id_map jsonb := '{}'::jsonb;
begin
  if p_access_level not in ('public', 'private') then
    raise exception 'Invalid route access level';
  end if;
  if jsonb_array_length(p_places) = 0 then
    raise exception 'A route requires at least one place';
  end if;

  select owner_id
  into current_owner_id
  from public.routes
  where id = p_route_id
  for update;

  if current_owner_id is null or current_owner_id <> (select auth.uid()) then
    raise exception 'Route not found or not owned by current user'
      using errcode = '42501';
  end if;

  update public.routes
  set title = btrim(p_title),
      description = btrim(p_description),
      city = btrim(p_city),
      access_level = p_access_level,
      estimated_duration_minutes = greatest(p_estimated_duration_minutes, 0),
      published_at = case
        when p_access_level = 'public' then coalesce(published_at, now())
        else null
      end
  where id = p_route_id;

  delete from public.route_tags where route_id = p_route_id;
  insert into public.route_tags (route_id, tag)
  select p_route_id, tag
  from (
    select distinct btrim(value) as tag
    from unnest(coalesce(p_tags, array[]::text[])) as value
  ) as normalized
  where tag <> '';

  update public.route_places
  set order_index = order_index + 1000000
  where route_id = p_route_id;

  for place_value in
    select value from jsonb_array_elements(p_places)
  loop
    place_client_key := place_value ->> 'client_key';

    if nullif(btrim(place_value ->> 'name'), '') is null then
      raise exception 'A place requires a name';
    end if;
    if nullif(btrim(place_value ->> 'address'), '') is null then
      raise exception 'A place requires an address';
    end if;

    normalized_place_name := pg_catalog.lower(
      pg_catalog.regexp_replace(
        pg_catalog.btrim(place_value ->> 'name'),
        '[[:space:]]+',
        '',
        'g'
      )
    );
    normalized_place_address := pg_catalog.lower(
      pg_catalog.regexp_replace(
        pg_catalog.btrim(place_value ->> 'address'),
        '[[:space:]]+',
        '',
        'g'
      )
    );

    requested_canonical_place_id := null;
    if coalesce(place_value ->> 'canonical_place_id', '') ~
       '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' then
      requested_canonical_place_id :=
        (place_value ->> 'canonical_place_id')::uuid;
    end if;

    select id
    into canonical_place_id_value
    from public.places
    where id = requested_canonical_place_id
      and normalized_name = normalized_place_name
      and normalized_address = normalized_place_address;

    if canonical_place_id_value is null then
      insert into public.places (
        name,
        address,
        category,
        latitude,
        longitude
      ) values (
        btrim(place_value ->> 'name'),
        btrim(place_value ->> 'address'),
        nullif(btrim(place_value ->> 'category'), ''),
        (place_value ->> 'latitude')::double precision,
        (place_value ->> 'longitude')::double precision
      )
      on conflict (normalized_name, normalized_address) do nothing;

      select id
      into canonical_place_id_value
      from public.places
      where normalized_name = normalized_place_name
        and normalized_address = normalized_place_address;
    end if;

    if canonical_place_id_value is null then
      raise exception 'Could not resolve canonical place';
    end if;

    existing_place_id := null;
    if coalesce(place_value ->> 'id', '') ~
       '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' then
      select id
      into existing_place_id
      from public.route_places
      where id = (place_value ->> 'id')::uuid
        and route_id = p_route_id;
    end if;

    if existing_place_id is null then
      insert into public.route_places (
        route_id, place_id, name, category, order_index, address, visited_at,
        memo, latitude, longitude, estimated_cost_won
      ) values (
        p_route_id,
        canonical_place_id_value,
        btrim(place_value ->> 'name'),
        btrim(place_value ->> 'category'),
        (place_value ->> 'order_index')::integer,
        btrim(place_value ->> 'address'),
        nullif(place_value ->> 'visited_at', '')::timestamptz,
        nullif(btrim(place_value ->> 'memo'), ''),
        (place_value ->> 'latitude')::double precision,
        (place_value ->> 'longitude')::double precision,
        (place_value ->> 'estimated_cost_won')::bigint
      )
      returning id into place_id_value;
    else
      place_id_value := existing_place_id;
      update public.route_places
      set place_id = canonical_place_id_value,
          name = btrim(place_value ->> 'name'),
          category = btrim(place_value ->> 'category'),
          order_index = (place_value ->> 'order_index')::integer,
          address = btrim(place_value ->> 'address'),
          visited_at = nullif(place_value ->> 'visited_at', '')::timestamptz,
          memo = nullif(btrim(place_value ->> 'memo'), ''),
          latitude = (place_value ->> 'latitude')::double precision,
          longitude = (place_value ->> 'longitude')::double precision,
          estimated_cost_won = (place_value ->> 'estimated_cost_won')::bigint
      where id = place_id_value and route_id = p_route_id;
    end if;

    place_ids := array_append(place_ids, place_id_value);
    place_id_map := place_id_map || jsonb_build_object(
      place_client_key,
      place_id_value
    );

    delete from public.route_place_purchases
    where place_id = place_id_value;
    insert into public.route_place_purchases (place_id, name, order_index)
    select place_id_value, btrim(value), ordinal - 1
    from jsonb_array_elements_text(
      coalesce(place_value -> 'purchased_items', '[]'::jsonb)
    ) with ordinality as item(value, ordinal)
    where btrim(value) <> '';
  end loop;

  delete from public.route_places
  where route_id = p_route_id
    and not (id = any(place_ids));

  select coalesce(array_agg(value ->> 'storage_path'), array[]::text[])
  into keep_photo_paths
  from jsonb_array_elements(p_photos);

  select coalesce(array_agg(storage_path), array[]::text[])
  into removed_storage_paths
  from public.route_photos
  where route_id = p_route_id
    and not (storage_path = any(keep_photo_paths));

  delete from public.route_photos
  where route_id = p_route_id
    and not (storage_path = any(keep_photo_paths));

  for photo_value in
    select value from jsonb_array_elements(p_photos)
  loop
    if exists (
      select 1
      from public.route_photos
      where storage_path = photo_value ->> 'storage_path'
        and route_id <> p_route_id
    ) then
      raise exception 'Photo path belongs to another route';
    end if;

    place_client_key := nullif(photo_value ->> 'place_client_key', '');
    place_id_value := case
      when place_client_key is null then null
      else (place_id_map ->> place_client_key)::uuid
    end;

    insert into public.route_photos (
      route_id, place_id, storage_path, order_index, captured_at
    ) values (
      p_route_id,
      place_id_value,
      photo_value ->> 'storage_path',
      (photo_value ->> 'order_index')::integer,
      nullif(photo_value ->> 'captured_at', '')::timestamptz
    )
    on conflict (storage_path) do update
    set place_id = excluded.place_id,
        order_index = excluded.order_index,
        captured_at = excluded.captured_at
    where route_photos.route_id = p_route_id;
  end loop;

  if p_cover_image_path is not null and not exists (
    select 1
    from public.route_photos
    where route_id = p_route_id
      and storage_path = p_cover_image_path
  ) then
    raise exception 'Cover image must belong to the route';
  end if;

  update public.routes
  set cover_image_path = p_cover_image_path
  where id = p_route_id;

  return jsonb_build_object(
    'place_ids', place_id_map,
    'removed_storage_paths', to_jsonb(removed_storage_paths)
  );
end;
$$;

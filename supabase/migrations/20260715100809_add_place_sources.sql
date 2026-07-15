create table public.place_sources (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  provider text not null,
  external_id text not null,
  source_name text,
  source_address text,
  created_by uuid default auth.uid()
    references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint place_sources_provider_not_blank
    check (length(btrim(provider)) > 0),
  constraint place_sources_external_id_not_blank
    check (length(btrim(external_id)) > 0),
  unique (provider, external_id)
);

create or replace function private.set_place_source_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.provider := pg_catalog.lower(pg_catalog.btrim(new.provider));
  new.external_id := pg_catalog.btrim(new.external_id);
  new.source_name := nullif(pg_catalog.btrim(new.source_name), '');
  new.source_address := nullif(pg_catalog.btrim(new.source_address), '');
  return new;
end;
$$;

revoke execute on function private.set_place_source_identity()
from public, anon, authenticated;

create trigger place_sources_set_identity
before insert or update of provider, external_id, source_name, source_address
on public.place_sources
for each row execute function private.set_place_source_identity();

create index place_sources_place_id_idx
on public.place_sources(place_id);

create index place_sources_created_by_idx
on public.place_sources(created_by)
where created_by is not null;

alter table public.place_sources enable row level security;

create policy place_sources_authenticated_read
on public.place_sources for select
to authenticated
using (true);

create policy place_sources_authenticated_insert
on public.place_sources for insert
to authenticated
with check (created_by = (select auth.uid()));

grant select on public.place_sources to authenticated;
grant insert (
  place_id,
  provider,
  external_id,
  source_name,
  source_address
) on public.place_sources to authenticated;

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
  source_provider text;
  source_external_id text;
  sourced_place_id_value uuid;
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

    source_provider := nullif(
      pg_catalog.lower(pg_catalog.btrim(place_value ->> 'place_provider')),
      ''
    );
    source_external_id := nullif(
      pg_catalog.btrim(place_value ->> 'external_place_id'),
      ''
    );
    canonical_place_id_value := null;

    if source_provider is not null and source_external_id is not null then
      select place_id
      into canonical_place_id_value
      from public.place_sources
      where provider = source_provider
        and external_id = source_external_id;
    end if;

    requested_canonical_place_id := null;
    if coalesce(place_value ->> 'canonical_place_id', '') ~
       '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' then
      requested_canonical_place_id :=
        (place_value ->> 'canonical_place_id')::uuid;
    end if;

    if canonical_place_id_value is null then
      select id
      into canonical_place_id_value
      from public.places
      where id = requested_canonical_place_id
        and normalized_name = normalized_place_name
        and normalized_address = normalized_place_address;
    end if;

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

    if source_provider is not null and source_external_id is not null then
      insert into public.place_sources (
        place_id,
        provider,
        external_id,
        source_name,
        source_address
      ) values (
        canonical_place_id_value,
        source_provider,
        source_external_id,
        btrim(place_value ->> 'name'),
        btrim(place_value ->> 'address')
      )
      on conflict (provider, external_id) do nothing;

      select place_id
      into sourced_place_id_value
      from public.place_sources
      where provider = source_provider
        and external_id = source_external_id;

      canonical_place_id_value := sourced_place_id_value;
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

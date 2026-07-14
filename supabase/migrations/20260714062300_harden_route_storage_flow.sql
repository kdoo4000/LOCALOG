alter table public.routes
add column is_download_copy boolean not null default false;

update public.routes
set is_download_copy = true
where source_route_id is not null;

create index routes_public_original_published_idx
on public.routes (published_at desc, id desc)
where access_level = 'public' and is_download_copy = false;

update public.route_photos as photo
set place_id = null
where place_id is not null
  and not exists (
    select 1
    from public.route_places as place
    where place.id = photo.place_id
      and place.route_id = photo.route_id
  );

alter table public.route_places
add constraint route_places_id_route_id_unique unique (id, route_id);

alter table public.route_photos
drop constraint route_photos_place_id_fkey;

alter table public.route_photos
add constraint route_photos_place_route_fkey
foreign key (place_id, route_id)
references public.route_places (id, route_id)
on delete set null (place_id);

update public.routes as route
set cover_image_path = null
where cover_image_path is not null
  and not exists (
    select 1
    from public.route_photos as photo
    where photo.route_id = route.id
      and photo.storage_path = route.cover_image_path
  );

create table public.route_downloads (
  route_id uuid not null references public.routes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (route_id, user_id)
);

create index route_downloads_user_id_idx
on public.route_downloads (user_id);

create table public.route_likes (
  route_id uuid not null references public.routes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  is_positive boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (route_id, user_id)
);

create index route_likes_user_id_idx
on public.route_likes (user_id);

create trigger route_likes_set_updated_at
before update on public.route_likes
for each row execute function private.set_updated_at();

alter table public.route_downloads enable row level security;
alter table public.route_likes enable row level security;

create policy route_downloads_insert_own
on public.route_downloads for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.routes
    where routes.id = route_downloads.route_id
      and routes.access_level = 'public'
  )
);

create policy route_downloads_read_own_or_route_owner
on public.route_downloads for select
to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1
    from public.routes
    where routes.id = route_downloads.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_likes_insert_own
on public.route_likes for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.routes
    where routes.id = route_likes.route_id
      and routes.access_level = 'public'
  )
);

create policy route_likes_update_own
on public.route_likes for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy route_likes_delete_own
on public.route_likes for delete
to authenticated
using (user_id = (select auth.uid()));

create policy route_likes_read_own_or_route_owner
on public.route_likes for select
to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1
    from public.routes
    where routes.id = route_likes.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create or replace function private.sync_route_download_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_route_id uuid;
begin
  target_route_id := case
    when tg_op = 'DELETE' then old.route_id
    else new.route_id
  end;
  update public.routes
  set download_count = (
    select count(*)
    from public.route_downloads
    where route_id = target_route_id
  )
  where id = target_route_id;
  return null;
end;
$$;

create or replace function private.sync_route_upvote_ratio()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_route_id uuid;
begin
  target_route_id := case
    when tg_op = 'DELETE' then old.route_id
    else new.route_id
  end;
  update public.routes
  set upvote_ratio = coalesce((
    select avg(case when is_positive then 1.0 else 0.0 end)
    from public.route_likes
    where route_id = target_route_id
  ), 0)
  where id = target_route_id;
  return null;
end;
$$;

revoke execute on function private.sync_route_download_count()
from public, anon, authenticated;
revoke execute on function private.sync_route_upvote_ratio()
from public, anon, authenticated;

create trigger route_downloads_sync_count
after insert or delete on public.route_downloads
for each row execute function private.sync_route_download_count();

create trigger route_likes_sync_ratio
after insert or update or delete on public.route_likes
for each row execute function private.sync_route_upvote_ratio();

grant select, insert on public.route_downloads to authenticated;
grant select, insert, update, delete on public.route_likes to authenticated;

revoke insert, update on public.routes from authenticated;
grant insert (
  owner_id,
  source_route_id,
  title,
  description,
  city,
  access_level,
  cover_image_path,
  estimated_duration_minutes,
  published_at,
  is_download_copy
) on public.routes to authenticated;
grant update (
  title,
  description,
  city,
  access_level,
  cover_image_path,
  estimated_duration_minutes,
  published_at
) on public.routes to authenticated;

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
        route_id, name, category, order_index, address, visited_at, memo,
        latitude, longitude, estimated_cost_won
      ) values (
        p_route_id,
        btrim(place_value ->> 'name'),
        btrim(place_value ->> 'category'),
        (place_value ->> 'order_index')::integer,
        nullif(btrim(place_value ->> 'address'), ''),
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
      set name = btrim(place_value ->> 'name'),
          category = btrim(place_value ->> 'category'),
          order_index = (place_value ->> 'order_index')::integer,
          address = nullif(btrim(place_value ->> 'address'), ''),
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

revoke execute on function public.save_route_revision(
  uuid, text, text, text, text, integer, text[], jsonb, jsonb, text
) from public, anon;
grant execute on function public.save_route_revision(
  uuid, text, text, text, text, integer, text[], jsonb, jsonb, text
) to authenticated;

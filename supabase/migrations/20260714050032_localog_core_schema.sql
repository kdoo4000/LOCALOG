create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'LOCALOG 여행자',
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_not_blank check (length(btrim(display_name)) > 0)
);

create table public.routes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  source_route_id uuid references public.routes(id) on delete set null,
  title text not null,
  description text not null default '',
  city text not null,
  access_level text not null default 'private',
  cover_image_path text,
  upvote_ratio numeric(5, 4) not null default 0,
  download_count bigint not null default 0,
  estimated_duration_minutes integer not null default 0,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint routes_title_not_blank check (length(btrim(title)) > 0),
  constraint routes_city_not_blank check (length(btrim(city)) > 0),
  constraint routes_access_level_valid check (access_level in ('public', 'private')),
  constraint routes_upvote_ratio_valid check (upvote_ratio between 0 and 1),
  constraint routes_download_count_valid check (download_count >= 0),
  constraint routes_duration_valid check (estimated_duration_minutes >= 0),
  constraint routes_publication_consistent check (
    (access_level = 'public' and published_at is not null)
    or (access_level = 'private' and published_at is null)
  )
);

create table public.route_places (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete cascade,
  name text not null,
  category text not null,
  order_index integer not null,
  address text,
  visited_at timestamptz,
  memo text,
  latitude double precision,
  longitude double precision,
  estimated_cost_won bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint route_places_name_not_blank check (length(btrim(name)) > 0),
  constraint route_places_category_not_blank check (length(btrim(category)) > 0),
  constraint route_places_order_valid check (order_index >= 0),
  constraint route_places_cost_valid check (
    estimated_cost_won is null or estimated_cost_won >= 0
  ),
  constraint route_places_location_pair check (
    (latitude is null and longitude is null)
    or (
      latitude between -90 and 90
      and longitude between -180 and 180
    )
  ),
  unique (route_id, order_index)
);

create table public.route_tags (
  route_id uuid not null references public.routes(id) on delete cascade,
  tag text not null,
  created_at timestamptz not null default now(),
  primary key (route_id, tag),
  constraint route_tags_tag_not_blank check (length(btrim(tag)) > 0)
);

create table public.route_photos (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete cascade,
  place_id uuid references public.route_places(id) on delete set null,
  storage_path text not null unique,
  order_index integer not null default 0,
  captured_at timestamptz,
  created_at timestamptz not null default now(),
  constraint route_photos_path_not_blank check (length(btrim(storage_path)) > 0),
  constraint route_photos_order_valid check (order_index >= 0)
);

create table public.route_place_purchases (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.route_places(id) on delete cascade,
  name text not null,
  amount_won bigint,
  order_index integer not null default 0,
  created_at timestamptz not null default now(),
  constraint route_place_purchases_name_not_blank check (length(btrim(name)) > 0),
  constraint route_place_purchases_amount_valid check (
    amount_won is null or amount_won >= 0
  ),
  constraint route_place_purchases_order_valid check (order_index >= 0)
);

create index routes_owner_id_idx on public.routes(owner_id);
create index routes_source_route_id_idx on public.routes(source_route_id);
create index routes_public_published_idx
  on public.routes(published_at desc)
  where access_level = 'public';
create index route_places_route_id_idx on public.route_places(route_id);
create index route_tags_tag_idx on public.route_tags(tag);
create index route_photos_route_id_idx on public.route_photos(route_id);
create index route_photos_place_id_idx on public.route_photos(place_id);
create index route_place_purchases_place_id_idx
  on public.route_place_purchases(place_id);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create trigger routes_set_updated_at
before update on public.routes
for each row execute function private.set_updated_at();

create trigger route_places_set_updated_at
before update on public.route_places
for each row execute function private.set_updated_at();

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_path)
  values (
    new.id,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), 'LOCALOG 여행자'),
    nullif(btrim(new.raw_user_meta_data ->> 'avatar_path'), '')
  );
  return new;
end;
$$;

revoke execute on function private.set_updated_at() from public, anon, authenticated;
revoke execute on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

alter table public.profiles enable row level security;
alter table public.routes enable row level security;
alter table public.route_places enable row level security;
alter table public.route_tags enable row level security;
alter table public.route_photos enable row level security;
alter table public.route_place_purchases enable row level security;

create policy profiles_public_read
on public.profiles for select
to anon, authenticated
using (true);

create policy profiles_owner_update
on public.profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy routes_public_or_owner_read
on public.routes for select
to anon, authenticated
using (access_level = 'public' or (select auth.uid()) = owner_id);

create policy routes_owner_insert
on public.routes for insert
to authenticated
with check ((select auth.uid()) = owner_id);

create policy routes_owner_update
on public.routes for update
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

create policy routes_owner_delete
on public.routes for delete
to authenticated
using ((select auth.uid()) = owner_id);

create policy route_places_parent_read
on public.route_places for select
to anon, authenticated
using (
  exists (
    select 1 from public.routes
    where routes.id = route_places.route_id
      and (routes.access_level = 'public' or routes.owner_id = (select auth.uid()))
  )
);

create policy route_places_owner_insert
on public.route_places for insert
to authenticated
with check (
  exists (
    select 1 from public.routes
    where routes.id = route_places.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_places_owner_update
on public.route_places for update
to authenticated
using (
  exists (
    select 1 from public.routes
    where routes.id = route_places.route_id
      and routes.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.routes
    where routes.id = route_places.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_places_owner_delete
on public.route_places for delete
to authenticated
using (
  exists (
    select 1 from public.routes
    where routes.id = route_places.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_tags_parent_read
on public.route_tags for select
to anon, authenticated
using (
  exists (
    select 1 from public.routes
    where routes.id = route_tags.route_id
      and (routes.access_level = 'public' or routes.owner_id = (select auth.uid()))
  )
);

create policy route_tags_owner_insert
on public.route_tags for insert
to authenticated
with check (
  exists (
    select 1 from public.routes
    where routes.id = route_tags.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_tags_owner_delete
on public.route_tags for delete
to authenticated
using (
  exists (
    select 1 from public.routes
    where routes.id = route_tags.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_photos_parent_read
on public.route_photos for select
to anon, authenticated
using (
  exists (
    select 1 from public.routes
    where routes.id = route_photos.route_id
      and (routes.access_level = 'public' or routes.owner_id = (select auth.uid()))
  )
);

create policy route_photos_owner_insert
on public.route_photos for insert
to authenticated
with check (
  exists (
    select 1 from public.routes
    where routes.id = route_photos.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_photos_owner_update
on public.route_photos for update
to authenticated
using (
  exists (
    select 1 from public.routes
    where routes.id = route_photos.route_id
      and routes.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.routes
    where routes.id = route_photos.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_photos_owner_delete
on public.route_photos for delete
to authenticated
using (
  exists (
    select 1 from public.routes
    where routes.id = route_photos.route_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_place_purchases_parent_read
on public.route_place_purchases for select
to anon, authenticated
using (
  exists (
    select 1
    from public.route_places
    join public.routes on routes.id = route_places.route_id
    where route_places.id = route_place_purchases.place_id
      and (routes.access_level = 'public' or routes.owner_id = (select auth.uid()))
  )
);

create policy route_place_purchases_owner_insert
on public.route_place_purchases for insert
to authenticated
with check (
  exists (
    select 1
    from public.route_places
    join public.routes on routes.id = route_places.route_id
    where route_places.id = route_place_purchases.place_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_place_purchases_owner_update
on public.route_place_purchases for update
to authenticated
using (
  exists (
    select 1
    from public.route_places
    join public.routes on routes.id = route_places.route_id
    where route_places.id = route_place_purchases.place_id
      and routes.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.route_places
    join public.routes on routes.id = route_places.route_id
    where route_places.id = route_place_purchases.place_id
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_place_purchases_owner_delete
on public.route_place_purchases for delete
to authenticated
using (
  exists (
    select 1
    from public.route_places
    join public.routes on routes.id = route_places.route_id
    where route_places.id = route_place_purchases.place_id
      and routes.owner_id = (select auth.uid())
  )
);

grant select on public.profiles to anon, authenticated;
grant update on public.profiles to authenticated;
grant select on public.routes, public.route_places, public.route_tags,
  public.route_photos, public.route_place_purchases to anon, authenticated;
grant insert, update, delete on public.routes, public.route_places,
  public.route_photos, public.route_place_purchases to authenticated;
grant insert, delete on public.route_tags to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'route-photos',
  'route-photos',
  false,
  15728640,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
);

create policy route_photo_objects_read
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'route-photos'
  and exists (
    select 1 from public.routes
    where routes.owner_id::text = (storage.foldername(name))[1]
      and routes.id::text = (storage.foldername(name))[2]
      and (routes.access_level = 'public' or routes.owner_id = (select auth.uid()))
  )
);

create policy route_photo_objects_insert
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'route-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.routes
    where routes.id::text = (storage.foldername(name))[2]
      and routes.owner_id = (select auth.uid())
  )
);

create policy route_photo_objects_update
on storage.objects for update
to authenticated
using (
  bucket_id = 'route-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'route-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy route_photo_objects_delete
on storage.objects for delete
to authenticated
using (
  bucket_id = 'route-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

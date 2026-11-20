create function private.uuid_handle(p_id uuid)
returns text language plpgsql immutable strict set search_path = '' as $$
declare
  n numeric := 0;
  encoded text := '';
  alphabet constant text := 'abcdefghijklmnopqrstuvwxyz234567';
  bytes bytea := pg_catalog.uuid_send(p_id);
begin
  for i in 0..15 loop
    n := n * 256 + pg_catalog.get_byte(bytes, i);
  end loop;
  for i in 1..26 loop
    encoded := pg_catalog.substr(alphabet, pg_catalog.mod(n, 32)::integer + 1, 1) || encoded;
    n := pg_catalog.floor(n / 32);
  end loop;
  return 'u_' || encoded;
end;
$$;
revoke all on function private.uuid_handle(uuid) from public, anon, authenticated;

alter table public.profiles add column handle text;
update public.profiles set handle = private.uuid_handle(id);
alter table public.profiles alter column handle set not null;
alter table public.profiles add constraint profiles_handle_format check (
  handle ~ '^[a-z0-9][a-z0-9._]{1,28}[a-z0-9]$'
  and handle !~ '\.\.'
);
create unique index profiles_handle_unique on public.profiles (pg_catalog.lower(handle));

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, avatar_path, handle)
  values (
    new.id,
    coalesce(nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'display_name'), ''), 'LOCALOG 여행자'),
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'avatar_path'), ''),
    coalesce(
      nullif(pg_catalog.lower(pg_catalog.btrim(new.raw_user_meta_data ->> 'handle')), ''),
      private.uuid_handle(new.id)
    )
  );
  return new;
end;
$$;

drop policy user_follows_read on public.user_follows;
create policy user_follows_read on public.user_follows for select to authenticated using (true);

alter table public.profiles drop constraint profiles_handle_format;
alter table public.profiles add constraint profiles_handle_format check (
  handle ~ '^[A-Za-z0-9][A-Za-z0-9._]{1,28}[A-Za-z0-9]$'
  and handle !~ '\.\.'
);

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, avatar_path, handle)
  values (
    new.id,
    coalesce(nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'display_name'), ''), 'LOCALOG 여행자'),
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'avatar_path'), ''),
    coalesce(
      nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'handle'), ''),
      private.uuid_handle(new.id)
    )
  );
  return new;
end;
$$;
revoke execute on function private.handle_new_user() from public, anon, authenticated;

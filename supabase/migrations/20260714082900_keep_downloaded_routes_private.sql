update public.routes
set access_level = 'private',
    published_at = null
where is_download_copy = true;

alter table public.routes
add constraint routes_download_copy_private
check (
  not is_download_copy
  or (access_level = 'private' and published_at is null)
);

create or replace function private.keep_downloaded_route_private()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_download_copy then
    new.access_level := 'private';
    new.published_at := null;
  end if;
  return new;
end;
$$;

revoke execute on function private.keep_downloaded_route_private()
from public, anon, authenticated;

create trigger routes_keep_downloaded_private
before insert or update of is_download_copy, access_level, published_at
on public.routes
for each row execute function private.keep_downloaded_route_private();

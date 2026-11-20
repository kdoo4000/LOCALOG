-- Profile photos are visible wherever the public profile is visible.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-avatars', 'profile-avatars', true, 5242880, array['image/png']);

create policy profile_avatars_owner_read on storage.objects
for select to authenticated
using (bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy profile_avatars_owner_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy profile_avatars_owner_delete on storage.objects
for delete to authenticated
using (bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text);

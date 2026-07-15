alter table public.places
add column created_by uuid
default auth.uid()
references public.profiles(id)
on delete set null;

drop policy places_authenticated_insert on public.places;

create policy places_authenticated_insert
on public.places for insert
to authenticated
with check (created_by = (select auth.uid()));

create index places_created_by_idx
on public.places(created_by)
where created_by is not null;

create index route_photos_place_route_idx
on public.route_photos (place_id, route_id)
where place_id is not null;

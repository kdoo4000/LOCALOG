begin;
do $$
declare
  owner_id_value uuid;
  plan_id_value uuid;
  first_day uuid;
  middle_day uuid;
  last_day uuid;
  route_id_value uuid;
  ordinary_id uuid;
  source_id uuid;
  denied boolean := false;
  hotel_a jsonb := '{"id":"test-a","name":"숙소 검증 A","address":"서울 중구","source":"test","category":"호텔","latitude":37.56,"longitude":126.98}';
  hotel_b jsonb := '{"id":"test-b","name":"숙소 검증 B","address":"서울 종로구","source":"test","category":"호텔","latitude":37.58,"longitude":126.99}';
begin
  select id into strict owner_id_value from public.profiles limit 1;
  perform set_config('request.jwt.claim.sub',owner_id_value::text,true);
  perform set_config('role','authenticated',true);
  plan_id_value := public.create_travel_plan('숙소 기능 롤백 검증',array['서울특별시'],'2027-01-01','2027-01-03');
  select id into first_day from public.travel_plan_days where plan_id=plan_id_value and day_index=0;
  select id into middle_day from public.travel_plan_days where plan_id=plan_id_value and day_index=1;
  select id into last_day from public.travel_plan_days where plan_id=plan_id_value and day_index=2;
  route_id_value := public.create_planned_route(first_day,'검증 루트','서울',90,'[{"name":"일반 장소","category":"관광지","order_index":0}]');
  set constraints all immediate;
  set constraints all deferred;
  select id into ordinary_id from public.planned_route_places where planned_route_id=route_id_value;
  perform public.set_plan_day_accommodation(first_day,hotel_a);
  set constraints all immediate;
  set constraints all deferred;
  if not exists(select 1 from public.planned_route_places where id=ordinary_id and order_index=0) then
    raise exception 'Ordinary place identity changed';
  end if;
  if not exists(select 1 from public.planned_route_places where planned_route_id=route_id_value and name='숙소 검증 A' and order_index=1 and accommodation_role='end') then
    raise exception 'Arrival not added at the end';
  end if;
  if not exists(select 1 from public.planned_routes r join public.planned_route_places p on p.planned_route_id=r.id where r.plan_day_id=middle_day and p.accommodation_role='start' and p.order_index=0 and p.latitude=37.56) then
    raise exception 'Next day departure or coordinates missing';
  end if;
  perform public.set_plan_day_accommodation(middle_day,hotel_b);
  set constraints all immediate;
  set constraints all deferred;
  route_id_value := public.create_planned_route(middle_day,'중간 날 루트','서울',90,'[{"name":"공원","category":"관광지","order_index":0}]');
  set constraints all immediate;
  set constraints all deferred;
  if (select array_agg(name order by order_index) from public.planned_route_places where planned_route_id=route_id_value) <> array['숙소 검증 A','공원','숙소 검증 B'] then
    raise exception 'Manual route did not preserve both stays';
  end if;
  select id into ordinary_id from public.planned_route_places where planned_route_id=route_id_value and accommodation_role is null;
  perform public.set_plan_day_accommodation(first_day,hotel_b);
  set constraints all immediate;
  set constraints all deferred;
  if not exists(select 1 from public.planned_route_places where id=ordinary_id and name='공원') then
    raise exception 'Changing stay removed an ordinary place';
  end if;
  if exists(select 1 from public.planned_route_places p join public.planned_routes r on r.id=p.planned_route_id join public.travel_plan_days d on d.id=r.plan_day_id where d.plan_id=plan_id_value and p.name='숙소 검증 A') then
    raise exception 'Old automatic accommodation remains';
  end if;
  perform public.save_planned_route(route_id_value,'수정한 루트','서울',90,'[{"name":"공원","category":"관광지","order_index":0}]');
  set constraints all immediate;
  set constraints all deferred;
  if (select count(*) from public.planned_route_places where planned_route_id=route_id_value and accommodation_role is not null) <> 2 then
    raise exception 'Saving duplicated or removed automatic stays';
  end if;
  select id into source_id from public.routes where access_level='public' limit 1;
  if source_id is not null then
    route_id_value := public.copy_log_route_to_plan_day(source_id,middle_day);
    set constraints all immediate;
    set constraints all deferred;
    if (select count(*) from public.planned_route_places where planned_route_id=route_id_value and accommodation_role is not null) <> 2 then
      raise exception 'Imported route lost accommodation';
    end if;
  end if;
  perform public.set_plan_day_accommodation(first_day,null);
  set constraints all immediate;
  set constraints all deferred;
  if exists(select 1 from public.planned_route_places where planned_route_id=route_id_value and accommodation_role='start') then
    raise exception 'Removing stay left next-day departure';
  end if;
  begin
    perform public.set_plan_day_accommodation(last_day,hotel_a);
  exception when others then denied := true;
  end;
  if not denied then raise exception 'Last-day accommodation was accepted'; end if;
  denied := false;
  begin
    perform public.set_plan_day_accommodation(first_day,'{}');
  exception when check_violation then denied := true;
  end;
  if not denied then raise exception 'Invalid accommodation payload was accepted'; end if;
  perform public.update_travel_plan(plan_id_value,'기간 축소 검증',array['서울특별시'],'2027-01-01','2027-01-02');
  set constraints all immediate;
  set constraints all deferred;
  if exists(select 1 from public.travel_plan_days where id=middle_day and accommodation is not null) then
    raise exception 'Shortened trip retained accommodation on its last day';
  end if;
  if exists(select 1 from public.planned_route_places where planned_route_id=route_id_value and accommodation_role is not null) then
    raise exception 'Shortened trip retained obsolete accommodation stops';
  end if;
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  denied := false;
  begin
    perform public.set_plan_day_accommodation(first_day,hotel_a);
  exception when others then denied := true;
  end;
  if not denied then raise exception 'An unrelated user modified accommodation'; end if;
  perform set_config('request.jwt.claim.sub','',true);
  denied := false;
  begin
    perform public.set_plan_day_accommodation(first_day,hotel_a);
  exception when others then denied := true;
  end;
  if not denied then raise exception 'An unauthenticated caller modified accommodation'; end if;
end;
$$;
rollback;
select 'Accommodation storage, routes, editing, imports, date changes and RLS verified; all fixtures rolled back' as result;

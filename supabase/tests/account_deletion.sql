-- Disposable fixtures only. All changes are rolled back, including account deletion.
begin;
do $$
declare
  departing uuid := gen_random_uuid();
  successor uuid := gen_random_uuid();
  later_member uuid := gen_random_uuid();
  pending_member uuid := gen_random_uuid();
  shared_plan uuid := gen_random_uuid();
  solo_plan uuid := gen_random_uuid();
  owned_log uuid := gen_random_uuid();
  own_expense uuid := gen_random_uuid();
  other_expense uuid := gen_random_uuid();
  candidate uuid;
begin
  if has_function_privilege('authenticated', 'public.finish_account_deletion(uuid)', 'execute')
    or has_function_privilege('anon', 'public.prepare_account_deletion(uuid)', 'execute')
    or has_function_privilege('authenticated', 'public.account_deletion_files(uuid)', 'execute') then
    raise exception 'Deletion RPC exposed to clients';
  end if;
  foreach candidate in array array[departing, successor, later_member, pending_member] loop
    insert into auth.users(id,email) values(candidate, candidate::text || '@deletion-test.invalid');
    insert into public.profiles(id,display_name,handle)
      values(candidate,'Deletion test','t_' || substr(replace(candidate::text,'-',''),1,20))
      on conflict (id) do nothing;
  end loop;
  insert into public.travel_plans(id,owner_id,title,region_name,start_date,end_date) values
    (shared_plan,departing,'Shared deletion test','Seoul',current_date,current_date),
    (solo_plan,departing,'Solo deletion test','Seoul',current_date,current_date);
  insert into public.travel_plan_members(plan_id,user_id,invited_by,plan_title,status,created_at) values
    (shared_plan,pending_member,departing,'Shared deletion test','pending',now()-interval '3 days'),
    (shared_plan,successor,departing,'Shared deletion test','accepted',now()-interval '2 days'),
    (shared_plan,later_member,departing,'Shared deletion test','accepted',now()-interval '1 day');
  insert into public.routes(id,owner_id,title,city) values(owned_log,departing,'Own log','Seoul');
  insert into public.travel_expenses(id,plan_id,payer_id,created_by,title,amount,receipt_path) values
    (own_expense,shared_plan,departing,departing,'Own receipt',100,shared_plan::text || '/' || own_expense::text || '/receipt.jpg'),
    (other_expense,shared_plan,successor,successor,'Keep receipt',100,shared_plan::text || '/' || other_expense::text || '/receipt.jpg');
  insert into public.travel_expense_shares(expense_id,user_id,amount) values
    (own_expense,departing,50),(own_expense,successor,50),
    (other_expense,departing,50),(other_expense,successor,50);
  insert into storage.objects(bucket_id,name,owner_id) values
    ('route-photos',departing::text || '/' || owned_log::text || '/photo.jpg',departing::text),
    ('profile-avatars',departing::text || '/avatar.jpg',departing::text),
    ('route-photos',departing::text || '/orphan.jpg',departing::text),
    ('travel-receipts',shared_plan::text || '/' || own_expense::text || '/receipt.jpg',departing::text),
    ('travel-receipts',shared_plan::text || '/' || other_expense::text || '/receipt.jpg',successor::text),
    ('travel-receipts',solo_plan::text || '/orphan/receipt.jpg',successor::text),
    ('profile-avatars',successor::text || '/keep.jpg',successor::text);
  perform public.prepare_account_deletion(departing);
  if (select owner_id from public.travel_plans where id=shared_plan) <> successor then
    raise exception 'Earliest accepted member did not inherit plan';
  end if;
  if exists(select 1 from public.travel_plan_members where plan_id=shared_plan and invited_by=departing)
    or exists(select 1 from public.travel_plan_members where plan_id=shared_plan and user_id=successor) then
    raise exception 'Transferred memberships were not updated';
  end if;
  perform public.prepare_account_deletion(departing);
  if (select count(*) from public.account_deletion_files(departing)) <> 5 then
    raise exception 'File manifest included another member or missed owned/orphan files';
  end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',departing,'role','authenticated')::text,true);
  begin
    insert into storage.objects(bucket_id,name,owner_id)
      values('route-photos',departing::text || '/late.jpg',departing::text);
    raise exception 'Pending account uploaded a file';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claims','{}',true);
  begin
    perform public.finish_account_deletion(departing);
    raise exception 'Account deleted before Storage cleanup';
  exception when raise_exception then
    if sqlerrm <> 'Account files must be deleted first' then raise; end if;
  end;
  -- Simulates successful Storage API removal only inside this rolled-back fixture.
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects o using public.account_deletion_files(departing) f
    where o.bucket_id=f.bucket_id and o.name=f.name;
  perform set_config('storage.allow_delete_query', 'false', true);
  perform public.finish_account_deletion(departing);
  if exists(select 1 from auth.users where id=departing)
    or exists(select 1 from public.profiles where id=departing)
    or exists(select 1 from public.routes where owner_id=departing)
    or exists(select 1 from public.travel_expenses where id=own_expense)
    or exists(select 1 from public.travel_expense_shares where user_id=departing)
    or exists(select 1 from public.travel_plans where id=solo_plan) then
    raise exception 'Departing account data survived deletion';
  end if;
  if not exists(select 1 from public.travel_plans where id=shared_plan and owner_id=successor)
    or not exists(select 1 from public.travel_expenses where id=other_expense and amount=100)
    or not exists(select 1 from public.travel_plan_members where plan_id=shared_plan and user_id=later_member)
    or not exists(select 1 from storage.objects where name=shared_plan::text || '/' || other_expense::text || '/receipt.jpg')
    or not exists(select 1 from storage.objects where name=successor::text || '/keep.jpg') then
    raise exception 'Another member lost plan, expense, membership or files';
  end if;
  perform public.prepare_account_deletion(successor);
  if (select owner_id from public.travel_plans where id=shared_plan) <> later_member then
    raise exception 'Inherited plan was not transferred when its new owner departed';
  end if;
end;
$$;
rollback;

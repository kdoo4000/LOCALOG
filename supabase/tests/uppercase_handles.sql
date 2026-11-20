-- Run inside a transaction and roll back to leave no test accounts.
do $$
declare
  test_id uuid := gen_random_uuid();
  other_id uuid := gen_random_uuid();
begin
  insert into auth.users(id, raw_user_meta_data)
  values(test_id, jsonb_build_object('handle', 'CaseCheck_AbC'));
  if (select handle from public.profiles where id = test_id) <> 'CaseCheck_AbC' then
    raise exception 'Signup lost handle case';
  end if;
  begin
    insert into auth.users(id, raw_user_meta_data)
    values(other_id, jsonb_build_object('handle', 'casecheck_abc'));
    raise exception 'Case-insensitive uniqueness failed';
  exception when unique_violation then null;
  end;
  begin
    update public.profiles set handle = 'Ab..Cd' where id = test_id;
    raise exception 'Invalid handle accepted';
  exception when check_violation then null;
  end;
end;
$$;

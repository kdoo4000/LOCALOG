create or replace function public.consume_naver_proxy_quota(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := pg_catalog.clock_timestamp();
  allowed boolean;
begin
  if p_user_id is null then return false; end if;

  insert into private.naver_proxy_rate_limits (
    user_id, window_started_at, request_count
  ) values (p_user_id, v_now, 1)
  on conflict (user_id) do update
  set window_started_at = case
        when private.naver_proxy_rate_limits.window_started_at <= v_now - interval '1 minute'
          then v_now
        else private.naver_proxy_rate_limits.window_started_at
      end,
      request_count = case
        when private.naver_proxy_rate_limits.window_started_at <= v_now - interval '1 minute'
          then 1
        else private.naver_proxy_rate_limits.request_count + 1
      end
  where private.naver_proxy_rate_limits.window_started_at <= v_now - interval '1 minute'
     or private.naver_proxy_rate_limits.request_count < 60
  returning true into allowed;

  return coalesce(allowed, false);
end;
$$;

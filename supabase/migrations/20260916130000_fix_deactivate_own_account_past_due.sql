-- Fixes deactivate_own_account() (20260916120000_add_deactivate_own_account.sql):
-- it read the raw client_custom_requests/company_custom_requests status
-- columns, which is technically correct against DB state but doesn't match
-- what the client actually sees. The client order list computes "Expired"
-- INSTANTLY, client-side, by comparing need_by (+1 day grace) against
-- DateTime.now() (_resolveOrderStatus, client_orders_page.dart/
-- client_order_page.dart) -- independent of the status column. The DB
-- column itself is only flipped to 'expired' later, by the
-- run_request_expiry_sweep() pg_cron job (every 15 minutes, see
-- 20260911140000_schedule_request_expiry_sweep.sql) or a best-effort
-- client-triggered write. So a request the user is SHOWN as "Expired" can
-- still read as an active, non-terminal status here for up to ~15 minutes,
-- incorrectly blocking deactivation.
--
-- Fix: exclude a request from the active-order count once it's past its
-- own need_by + 1 day grace, using the exact same formula the client UI
-- uses, regardless of what the status column currently holds -- so
-- eligibility always matches what the user was actually shown, not
-- whichever DB write happens to have landed yet.
create or replace function public.deactivate_own_account(p_confirm boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_uid uuid := auth.uid();
  found_row jsonb;
  v_table text;
  v_email text;
  v_is_client_like boolean;
  v_is_artist_like boolean;
  v_is_company boolean;
  v_active_count integer := 0;
  terminal_statuses text[] := array['delivered', 'declined', 'expired', 'cancelled', 'canceled'];
begin
  if caller_uid is null then
    return jsonb_build_object('result', 'error', 'message', 'not signed in');
  end if;

  select to_jsonb(t) || jsonb_build_object('_table', 'client_artist') into found_row
    from public.client_artist t where t.id = caller_uid limit 1;
  if found_row is null then
    select to_jsonb(t) || jsonb_build_object('_table', 'artist') into found_row
      from public.artist t where t.id = caller_uid limit 1;
  end if;
  if found_row is null then
    select to_jsonb(t) || jsonb_build_object('_table', 'client') into found_row
      from public.client t where t.id = caller_uid limit 1;
  end if;
  if found_row is null then
    select to_jsonb(t) || jsonb_build_object('_table', 'company') into found_row
      from public.company t where t.id = caller_uid limit 1;
  end if;

  if found_row is null then
    return jsonb_build_object('result', 'error', 'message', 'account not found');
  end if;

  v_table := found_row ->> '_table';
  v_email := lower(trim(coalesce(found_row ->> 'email', '')));
  v_is_client_like := v_table in ('client', 'client_artist');
  v_is_artist_like := v_table in ('artist', 'client_artist');
  v_is_company := v_table = 'company';

  -- Active-order counts, per the confirmed policy: anything before
  -- "delivered" blocks deactivation, EXCLUDING anything already past its
  -- own need_by + 1 day grace -- matching the client UI's own
  -- _resolveOrderStatus computed-"Expired" override exactly, not just the
  -- (slower) DB status column. open_to_artist_pool is deliberately NOT
  -- considered -- an unclaimed pool-open request doesn't obligate this
  -- artist to anything, only one they're actually assigned to does.
  if v_is_client_like then
    select v_active_count + count(*) into v_active_count
    from public.client_custom_requests r
    where (
      r.client_id = caller_uid
      or r.client_uid = caller_uid
      or (v_email <> '' and lower(coalesce(r.client_email, '')) = v_email)
    )
    and lower(trim(coalesce(r.client_status, r.status, ''))) <> all (terminal_statuses)
    and not (r.need_by is not null and now() > (r.need_by::date + interval '1 day'));
  end if;

  if v_is_artist_like and v_email <> '' then
    select v_active_count + count(*) into v_active_count
    from public.client_custom_requests r
    where lower(coalesce(r.selected_artist_email, r.artist_email, r.accepted_by_artist_email, '')) = v_email
      and lower(trim(coalesce(r.artist_status, r.status, ''))) <> all (terminal_statuses)
      and not (r.need_by is not null and now() > (r.need_by::date + interval '1 day'));

    select v_active_count + count(*) into v_active_count
    from public.company_custom_requests r
    where lower(coalesce(r.selected_artist_email, r.artist_email, r.accepted_by_artist_email, '')) = v_email
      and lower(trim(coalesce(r.artist_status, r.status, ''))) <> all (terminal_statuses)
      and not (r.need_by is not null and now() > (r.need_by::date + interval '1 day'));
  end if;

  if v_is_company then
    select v_active_count + count(*) into v_active_count
    from public.company_custom_requests r
    where (
      r.company_uid = caller_uid
      or r.requester_uid = caller_uid
      or r.created_by_uid = caller_uid
      or r.uid = caller_uid
      or (v_email <> '' and lower(coalesce(r.company_email, '')) = v_email)
      or (v_email <> '' and lower(coalesce(r.requester_email, '')) = v_email)
      or (v_email <> '' and lower(coalesce(r.client_email, '')) = v_email)
      or (v_email <> '' and lower(coalesce(r.email, '')) = v_email)
    )
    and lower(trim(coalesce(r.brand_status, r.status, ''))) <> all (terminal_statuses)
    and not (r.need_by is not null and now() > (r.need_by::date + interval '1 day'));
  end if;

  if v_active_count > 0 then
    return jsonb_build_object('result', 'blocked', 'active_order_count', v_active_count);
  end if;

  if not p_confirm then
    return jsonb_build_object('result', 'eligible');
  end if;

  if v_table = 'client' then
    update public.client set
      is_blocked = true, blocked = true,
      account_status = 'Blocked', panel_status = 'Blocked',
      updated_at = now()
    where id = caller_uid;
  elsif v_table = 'client_artist' then
    update public.client_artist set
      is_blocked = true, blocked = true,
      account_status = 'Blocked', panel_status = 'Blocked',
      updated_at = now()
    where id = caller_uid;
  elsif v_table = 'artist' then
    update public.artist set
      is_blocked = true, blocked = true, panel_status = 'Blocked',
      updated_at = now()
    where id = caller_uid;
  elsif v_table = 'company' then
    update public.company set
      is_blocked = true, blocked = true, account_status = 'Blocked',
      updated_at = now()
    where id = caller_uid;
  end if;

  if v_email <> '' and (v_is_client_like or v_is_artist_like) then
    update public.client set
      is_blocked = true, blocked = true,
      account_status = 'Blocked', panel_status = 'Blocked',
      updated_at = now()
    where lower(coalesce(email, '')) = v_email and id <> caller_uid;

    update public.artist set
      is_blocked = true, blocked = true, panel_status = 'Blocked',
      updated_at = now()
    where lower(coalesce(email, '')) = v_email and id <> caller_uid;

    update public.client_artist set
      is_blocked = true, blocked = true,
      account_status = 'Blocked', panel_status = 'Blocked',
      updated_at = now()
    where lower(coalesce(email, '')) = v_email and id <> caller_uid;
  end if;

  if v_email <> '' and v_is_company then
    update public.company set
      is_blocked = true, blocked = true, account_status = 'Blocked',
      updated_at = now()
    where lower(coalesce(email, '')) = v_email and id <> caller_uid;
  end if;

  return jsonb_build_object('result', 'deactivated');
exception
  when others then
    return jsonb_build_object('result', 'error', 'message', sqlerrm);
end;
$$;

grant execute on function public.deactivate_own_account(boolean) to authenticated;

-- Self-service account deactivation. isAccountBlocked() (login_page.dart)
-- and JNT-Admin's own deactivate toggle already read/write is_blocked/
-- blocked/account_status/panel_status on client/artist/client_artist/
-- company -- but those columns were only ever added directly against the
-- live DB, never captured in a tracked migration in this repo (this repo
-- has already been bitten by that kind of UAT/prod drift once, see commit
-- 41af418). Track them here with idempotent adds so they're finally in
-- migration history; this is a no-op on any environment where they
-- already exist.
alter table public.client
  add column if not exists is_blocked boolean not null default false,
  add column if not exists blocked boolean not null default false,
  add column if not exists account_status text,
  add column if not exists panel_status text;

alter table public.artist
  add column if not exists is_blocked boolean not null default false,
  add column if not exists blocked boolean not null default false,
  add column if not exists account_status text,
  add column if not exists panel_status text;

alter table public.client_artist
  add column if not exists is_blocked boolean not null default false,
  add column if not exists blocked boolean not null default false,
  add column if not exists account_status text,
  add column if not exists panel_status text;

alter table public.company
  add column if not exists is_blocked boolean not null default false,
  add column if not exists blocked boolean not null default false,
  add column if not exists account_status text,
  add column if not exists panel_status text;

-- Self-service account deactivation. The RLS "update own row" policies on
-- client/artist/client_artist/company already let a signed-in user change
-- any column on their own row (e.g. "client update own row"), but a plain
-- client-side .update() call would need 4 different per-table field
-- shapes duplicated in Dart (JNT-Admin's own deactivate toggle already
-- writes a different column subset per table -- artist has no
-- account_status column, company has no panel_status column) and would
-- have no server-side guard against deactivating with active orders still
-- in flight. This RPC centralizes both concerns server-side, matching
-- resolve_account_row_for_uid()'s style: security definer, scoped
-- strictly to auth.uid(), single round trip.
--
-- p_confirm = false is a read-only dry run: it only ever reports whether
-- the caller is currently eligible (no active orders), never writes.
-- p_confirm = true re-checks the exact same condition (closing the race
-- where an order goes active between an initial check and the user
-- confirming) and, only if still eligible, writes the blocking fields.
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

  -- Resolve the caller's row the same way resolve_account_row_for_uid()
  -- does: client_artist -> artist -> client -> company, first match.
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
  -- "delivered" blocks deactivation. open_to_artist_pool is deliberately
  -- NOT considered here (unlike the "artists read/update client requests"
  -- RLS policies) -- an unclaimed pool-open request doesn't obligate this
  -- artist to anything, only one they're actually assigned to does.
  if v_is_client_like then
    select v_active_count + count(*) into v_active_count
    from public.client_custom_requests r
    where (
      r.client_id = caller_uid
      or r.client_uid = caller_uid
      or (v_email <> '' and lower(coalesce(r.client_email, '')) = v_email)
    )
    and lower(trim(coalesce(r.client_status, r.status, ''))) <> all (terminal_statuses);
  end if;

  if v_is_artist_like and v_email <> '' then
    select v_active_count + count(*) into v_active_count
    from public.client_custom_requests r
    where lower(coalesce(r.selected_artist_email, r.artist_email, r.accepted_by_artist_email, '')) = v_email
      and lower(trim(coalesce(r.artist_status, r.status, ''))) <> all (terminal_statuses);

    select v_active_count + count(*) into v_active_count
    from public.company_custom_requests r
    where lower(coalesce(r.selected_artist_email, r.artist_email, r.accepted_by_artist_email, '')) = v_email
      and lower(trim(coalesce(r.artist_status, r.status, ''))) <> all (terminal_statuses);
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
    and lower(trim(coalesce(r.brand_status, r.status, ''))) <> all (terminal_statuses);
  end if;

  if v_active_count > 0 then
    return jsonb_build_object('result', 'blocked', 'active_order_count', v_active_count);
  end if;

  if not p_confirm then
    return jsonb_build_object('result', 'eligible');
  end if;

  -- Write the blocking fields, matching JNT-Admin's own per-table shape
  -- exactly (its deactivate toggle in clients_page.dart/artists_page.dart/
  -- brands_page.dart) so its list pages show Inactive/Blocked with no
  -- admin-side changes needed.
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

  -- Mirror by email across client/artist/client_artist (never company),
  -- matching JNT-Admin's own account_deactivation_mirror.dart scope
  -- exactly -- covers a legacy duplicate-email row under a different id
  -- that could otherwise still sign in after "deactivation".
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

-- Only meaningful for a signed-in caller (it keys off auth.uid()), so no
-- need for anon access.
grant execute on function public.deactivate_own_account(boolean) to authenticated;

-- Closes a gap in the existing "update own row" RLS policies (e.g.
-- "client update own row": USING (auth.uid() = id) WITH CHECK (auth.uid()
-- = id), no column allow-list), which today let a signed-in user flip
-- is_blocked/blocked back to false on their own row -- i.e. self-
-- reactivate -- via any direct REST/SQL update, bypassing the app UI
-- entirely. Rejects that specific transition unless the caller matches an
-- active admin_users row, using the exact predicate already used in this
-- schema's ~20 existing admin RLS policies. deactivate_own_account() only
-- ever sets these flags true, so it never trips this; JNT-Admin's own
-- reactivate action authenticates with an admin_users-matching session,
-- so it's unaffected.
create or replace function public.prevent_self_reactivation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
begin
  if coalesce(old.is_blocked, false) = true
     and coalesce(new.is_blocked, false) = false then
    select exists (
      select 1 from public.admin_users a
      where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
        and a.is_active = true
    ) into is_admin;

    if not is_admin then
      raise exception 'Only an administrator can reactivate this account.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prevent_self_reactivation_client on public.client;
create trigger trg_prevent_self_reactivation_client
before update of is_blocked on public.client
for each row execute function public.prevent_self_reactivation();

drop trigger if exists trg_prevent_self_reactivation_artist on public.artist;
create trigger trg_prevent_self_reactivation_artist
before update of is_blocked on public.artist
for each row execute function public.prevent_self_reactivation();

drop trigger if exists trg_prevent_self_reactivation_client_artist on public.client_artist;
create trigger trg_prevent_self_reactivation_client_artist
before update of is_blocked on public.client_artist
for each row execute function public.prevent_self_reactivation();

drop trigger if exists trg_prevent_self_reactivation_company on public.company;
create trigger trg_prevent_self_reactivation_company
before update of is_blocked on public.company
for each row execute function public.prevent_self_reactivation();

-- Makes request expiry time-driven instead of screen-open-driven. Until now,
-- 'expired' only got written when a client/brand/artist happened to have the
-- relevant list open (see _syncExpiredRequests / _expireCompanyPoolRequestsIfNeeded
-- in the Flutter app) -- a request whose deadline passed with nobody looking
-- just sat in its prior status indefinitely. This schedules a direct-SQL
-- sweep (no edge function / no net.http_post / no Vault secret needed,
-- unlike 20260909120100_schedule_mail_queue_worker.sql -- this never leaves
-- Postgres) that runs the same two-gate rule the Dart sweeps now implement:
--
--   client_custom_requests:  expired once no artist has accepted AND it is
--                             past need_by.
--   company_custom_requests: two deadlines -- before ANY client has
--                             accepted (single or group), the earlier
--                             request_accept_by date is the deadline; once a
--                             client has, the request runs to need_by
--                             waiting on an artist. 'cancelled' is reserved
--                             for an explicit user cancel action elsewhere
--                             in the app and is never written here.
--
-- This intentionally does not replicate the Dart notification layer's full
-- brand-recipient resolution (NotificationsService.resolveBrandRecipientEmails
-- also looks up a company's team members by UID) or its admin-role lookup
-- (_loadAdminEmails queries user/profile tables for role='admin') -- doing
-- that in SQL would mean re-deriving business logic that already lives, and
-- changes, in Dart. Brand recipients here are resolved from the request
-- row's own email columns/payload only, and the admin_notifications feed
-- row is inserted directly rather than fanning out to each admin's
-- user_notifications.

create or replace function public.expire_overdue_client_requests()
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  r record;
  reason text := 'Request was not accepted by artist, and it is past due.';
begin
  for r in
    select id, client_email, order_number, request_number, payload, details
    from public.client_custom_requests
    where status not in ('expired', 'cancelled', 'canceled', 'declined', 'delivered', 'shipped')
      and coalesce(accepted_by_artist_email, '') = ''
      and need_by is not null
      and now() > (need_by::date + interval '1 day')
  loop
    update public.client_custom_requests
    set status = 'expired',
        expired_at = now(),
        expired_notified_client = true,
        payload = coalesce(r.payload, '{}'::jsonb)
          || jsonb_build_object('status', 'expired', 'expiredReason', reason, 'expiredAt', now()),
        details = coalesce(r.details, '{}'::jsonb)
          || jsonb_build_object('status', 'expired', 'expiredReason', reason, 'expiredAt', now()),
        updated_at = now()
    where id = r.id;

    if coalesce(r.client_email, '') <> '' then
      insert into public.user_notifications
        (receiver_email, title, body, type, order_id, order_number, source_collection, read, extra, created_at, updated_at)
      values
        (lower(trim(r.client_email)), 'Request Expired', 'Your request is expired. Please resubmit',
         'request_expired', r.id::text, coalesce(nullif(r.order_number, ''), r.request_number, ''),
         'Client_Custom_Requests', false, jsonb_build_object('reason', reason), now(), now());
    end if;
  end loop;
end;
$function$;

create or replace function public.expire_overdue_company_requests()
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  r record;
  has_client_accepted boolean;
  deadline timestamptz;
  reason text;
  display_brand text;
  display_campaign text;
  display_order text;
  recipient text;
  recipients text[];
begin
  for r in
    select *
    from public.company_custom_requests
    where status not in ('expired', 'cancelled', 'canceled', 'declined', 'delivered', 'shipped')
      and coalesce(accepted_by_artist_email, '') = ''
  loop
    has_client_accepted :=
      coalesce(r.accepted_by_client_email, '') <> ''
      or (
        jsonb_typeof(coalesce(r.details -> 'acceptedGroupClientEmails', r.payload -> 'acceptedGroupClientEmails')) = 'array'
        and jsonb_array_length(coalesce(r.details -> 'acceptedGroupClientEmails', r.payload -> 'acceptedGroupClientEmails')) > 0
      );

    -- Before any client accepts, the earlier accept-by date is the
    -- deadline; once one has, the request runs to need_by waiting on an
    -- artist -- mirrors the Dart sweeps in brand_order_page.dart etc.
    deadline := case when has_client_accepted then r.need_by else coalesce(r.request_accept_by, r.need_by) end;
    if deadline is null or now() <= (deadline::date + interval '1 day') then
      continue;
    end if;

    reason := case
      when has_client_accepted then 'Request was not accepted by artist, and it is past due.'
      else 'Request was not accepted by any client, and it is past due.'
    end;

    update public.company_custom_requests
    set status = 'expired',
        expired_at = now(),
        expired_notified_client = true,
        expired_notified_brand_admin = true,
        expired_notified_accepted_client = (coalesce(r.accepted_by_client_email, '') <> ''),
        payload = coalesce(r.payload, '{}'::jsonb)
          || jsonb_build_object('status', 'expired', 'expiredReason', reason, 'expiredAt', now()),
        details = coalesce(r.details, '{}'::jsonb)
          || jsonb_build_object('status', 'expired', 'expiredReason', reason, 'expiredAt', now()),
        updated_at = now()
    where id = r.id;

    display_brand := coalesce(nullif(r.brand_name, ''), nullif(r.company_name, ''), 'Brand Company');
    display_campaign := coalesce(nullif(r.campaign_name, ''), nullif(r.title, ''), 'Campaign');
    display_order := coalesce(nullif(r.order_number, ''), r.id::text);

    if coalesce(r.accepted_by_client_email, '') <> '' then
      insert into public.user_notifications
        (receiver_email, title, body, type, order_id, order_number, source_collection, read, extra, created_at, updated_at)
      values
        (lower(trim(r.accepted_by_client_email)), 'Brand Request Expired',
         format('Your %s %s brand request %s has expired %s', display_brand, display_campaign, display_order, reason),
         'client_brand_request_expired', r.id::text, coalesce(r.order_number, ''),
         'Company_Custom_Requests', false, jsonb_build_object('reason', reason), now(), now());
    end if;

    -- Brand recipients resolved from this row's own email columns/payload
    -- only -- a deliberately simpler stand-in for
    -- NotificationsService.resolveBrandRecipientEmails (see header note).
    select array_agg(distinct e) into recipients
    from unnest(array[
      lower(trim(coalesce(r.company_email, ''))),
      lower(trim(coalesce(r.requester_email, ''))),
      lower(trim(coalesce(r.email, ''))),
      lower(trim(coalesce(r.payload ->> 'brandEmail', ''))),
      lower(trim(coalesce(r.details ->> 'brandEmail', ''))),
      lower(trim(coalesce(r.payload ->> 'companyEmail', ''))),
      lower(trim(coalesce(r.details ->> 'companyEmail', '')))
    ]) as e
    where e <> '' and position('@' in e) > 0
      and e <> lower(trim(coalesce(r.accepted_by_client_email, '')));

    foreach recipient in array coalesce(recipients, array[]::text[])
    loop
      insert into public.user_notifications
        (receiver_email, title, body, type, order_id, order_number, source_collection, read, extra, created_at, updated_at)
      values
        (recipient, 'Brand Request Expired',
         format('Your %s brand request %s has expired %s', display_campaign, display_order, reason),
         'brand_request_expired', r.id::text, coalesce(r.order_number, ''),
         'Company_Custom_Requests', false, jsonb_build_object('reason', reason), now(), now());
    end loop;

    insert into public.admin_notifications
      (type, source, request_id, title, message, brand_name, campaign_name, date_label, event_at, payload, created_at, updated_at)
    values
      ('admin_brand_request_expired', 'Company_Custom_Requests', r.id::text, 'Brand Request Expired',
       format('%s %s brand request %s has expired %s', display_brand, display_campaign, display_order, reason),
       r.brand_name, r.campaign_name, now()::text, now(),
       jsonb_build_object('reason', reason, 'orderId', r.id, 'orderNumber', r.order_number, 'sourceCollection', 'Company_Custom_Requests'),
       now(), now());
  end loop;
end;
$function$;

create or replace function public.run_request_expiry_sweep()
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  lock_key constant bigint := hashtextextended('run_request_expiry_sweep', 0);
begin
  -- Skip this tick rather than run concurrently with one still in progress
  -- from a prior tick (e.g. if the sweep is ever slow or the schedule is
  -- tightened) -- each pg_cron run gets its own session, so this lock is
  -- released automatically when that session ends even if something below
  -- raises.
  if not pg_try_advisory_lock(lock_key) then
    return;
  end if;

  perform public.expire_overdue_client_requests();
  perform public.expire_overdue_company_requests();

  perform pg_advisory_unlock(lock_key);
end;
$function$;

-- Callable only by the scheduler / service role -- this runs a bulk,
-- unscoped write across every open request and was never meant to be
-- triggered by client code (unlike the old per-row expire_*_custom_request
-- RPCs it supersedes).
revoke all on function public.expire_overdue_client_requests() from public, anon, authenticated;
revoke all on function public.expire_overdue_company_requests() from public, anon, authenticated;
revoke all on function public.run_request_expiry_sweep() from public, anon, authenticated;
grant execute on function public.run_request_expiry_sweep() to service_role;

create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  perform cron.unschedule('expire-overdue-requests');
exception when others then
  null; -- job didn't exist yet -- fine on a first run.
end $$;

-- Every 15 minutes: the expiry rule already carries a 1-day grace window
-- past each deadline, so this doesn't need mail-queue-worker's 2-minute
-- cadence.
select cron.schedule(
  'expire-overdue-requests',
  '*/15 * * * *',
  $$select public.run_request_expiry_sweep();$$
);

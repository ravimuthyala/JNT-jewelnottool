-- Delivery-deadline reminder for the artist once they've actually taken on
-- the work (as opposed to 20260914120000/20260916150000, which remind
-- people to ACCEPT a request in the first place). Covers both request
-- shapes in the app:
--
--   company_custom_requests (brand request): the artist only "comes in"
--   once the client has accepted (mirrors the has_client_accepted gate in
--   expire_overdue_company_requests, 20260911140000) -- so this also
--   requires the artist to have accepted. Starting 5 days before need_by,
--   once a day through need_by, remind the artist to deliver to the client.
--
--   client_custom_requests (a client's own request straight to an artist,
--   no brand involved): no separate client-accept step -- the client IS the
--   requester -- so this only requires the artist to have accepted. Same
--   5-days-before-need_by daily cadence, remind the artist to deliver to
--   the client.
--
-- Neither gate cares whether the artist was hand-picked (Direct) or matched
-- through the artist pool (Standard) -- accepted_by_artist_email is set the
-- same way either way once someone accepts, so both assignment types get
-- the reminder.
--
-- Both stop once the request leaves an active state (delivered/shipped/
-- completed/cancelled/expired/declined) and dedupe to one notification per
-- request per day via user_notifications, same as the accept-reminders.
--
-- Both now also queue an SMS (public.resolve_contact_phone, 20260916135000)
-- alongside the in-app user_notifications row, drained by send-queued-sms
-- (20260917120000) -- stays SIMULATED until Twilio secrets are deployed;
-- see that function's own header comment.

create or replace function public.send_brand_artist_delivery_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  r record;
  has_client_accepted boolean;
  display_brand text;
  display_campaign text;
  display_order text;
  display_client text;
  need_by_display text;
  body_text text;
  sms_text text;
  phone text;
begin
  for r in
    select *
    from public.company_custom_requests
    where status not in ('expired', 'cancelled', 'canceled', 'declined', 'delivered', 'shipped', 'completed')
      and coalesce(accepted_by_artist_email, '') <> ''
      and need_by is not null
      and now()::date between (need_by::date - interval '5 days')::date
        and need_by::date
      and not exists (
        select 1 from public.user_notifications n
        where n.order_id = r.id::text
          and n.type = 'brand_artist_delivery_reminder'
          and n.created_at::date = now()::date
      )
  loop
    has_client_accepted :=
      coalesce(r.accepted_by_client_email, '') <> ''
      or (
        jsonb_typeof(coalesce(r.details -> 'acceptedGroupClientEmails', r.payload -> 'acceptedGroupClientEmails')) = 'array'
        and jsonb_array_length(coalesce(r.details -> 'acceptedGroupClientEmails', r.payload -> 'acceptedGroupClientEmails')) > 0
      );
    if not has_client_accepted then
      continue;
    end if;

    display_brand := coalesce(nullif(r.brand_name, ''), nullif(r.company_name, ''), 'Brand Company');
    display_campaign := coalesce(nullif(r.campaign_name, ''), nullif(r.title, ''), 'Campaign');
    display_order := coalesce(nullif(r.order_number, ''), r.id::text);
    display_client := coalesce(
      nullif(r.accepted_by_client_name, ''),
      nullif(r.accepted_client_name, ''),
      nullif(r.selected_client, ''),
      nullif(r.client_name, ''),
      'the client'
    );
    need_by_display := to_char(r.need_by::date, 'MM/DD/YYYY');

    body_text := format(
      'Your artwork for %s %s brand request %s should be delivered to %s by %s.',
      display_brand, display_campaign, display_order, display_client, need_by_display
    );

    insert into public.user_notifications
      (receiver_email, title, body, type, order_id, order_number, source_collection, read, extra, created_at, updated_at)
    values
      (lower(trim(r.accepted_by_artist_email)), 'Reminder: Delivery due soon', body_text,
       'brand_artist_delivery_reminder', r.id::text, coalesce(r.order_number, ''),
       'Company_Custom_Requests', false,
       jsonb_build_object('needBy', need_by_display), now(), now());

    phone := public.resolve_contact_phone(r.accepted_by_artist_email);
    if phone is not null then
      sms_text := format(
        'JNT: Your artwork for %s brand request %s should be delivered to %s by %s.',
        display_brand, display_order, display_client, need_by_display
      );
      insert into public.sms_outbox (to_number, message, status, created_at)
      values (phone, sms_text, 'queued', now());
    end if;
  end loop;
end;
$function$;

create or replace function public.send_client_artist_delivery_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  r record;
  display_campaign text;
  display_order text;
  display_client text;
  need_by_display text;
  body_text text;
  sms_text text;
  phone text;
begin
  for r in
    select *
    from public.client_custom_requests
    where status not in ('expired', 'cancelled', 'canceled', 'declined', 'delivered', 'shipped', 'completed')
      and coalesce(accepted_by_artist_email, '') <> ''
      and need_by is not null
      and now()::date between (need_by::date - interval '5 days')::date
        and need_by::date
      and not exists (
        select 1 from public.user_notifications n
        where n.order_id = r.id::text
          and n.type = 'client_artist_delivery_reminder'
          and n.created_at::date = now()::date
      )
  loop
    display_campaign := coalesce(nullif(r.campaign_name, ''), nullif(r.title, ''), 'Request');
    display_order := coalesce(nullif(r.order_number, ''), nullif(r.request_number, ''), r.id::text);
    display_client := coalesce(nullif(r.client_name, ''), 'the client');
    need_by_display := coalesce(
      nullif(r.need_by_display, ''),
      to_char(r.need_by::date, 'MM/DD/YYYY')
    );

    body_text := format(
      'Your artwork for %s request %s should be delivered to %s by %s.',
      display_campaign, display_order, display_client, need_by_display
    );

    insert into public.user_notifications
      (receiver_email, title, body, type, order_id, order_number, source_collection, read, extra, created_at, updated_at)
    values
      (lower(trim(r.accepted_by_artist_email)), 'Reminder: Delivery due soon', body_text,
       'client_artist_delivery_reminder', r.id::text, coalesce(r.order_number, ''),
       'Client_Custom_Requests', false,
       jsonb_build_object('needBy', need_by_display), now(), now());

    phone := public.resolve_contact_phone(r.accepted_by_artist_email);
    if phone is not null then
      sms_text := format(
        'JNT: Your artwork for %s request %s should be delivered to %s by %s.',
        display_campaign, display_order, display_client, need_by_display
      );
      insert into public.sms_outbox (to_number, message, status, created_at)
      values (phone, sms_text, 'queued', now());
    end if;
  end loop;
end;
$function$;

create or replace function public.run_artist_delivery_reminder_sweep()
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  lock_key constant bigint := hashtextextended('run_artist_delivery_reminder_sweep', 0);
begin
  if not pg_try_advisory_lock(lock_key) then
    return;
  end if;

  perform public.send_brand_artist_delivery_reminders();
  perform public.send_client_artist_delivery_reminders();

  perform pg_advisory_unlock(lock_key);
end;
$function$;

revoke all on function public.send_brand_artist_delivery_reminders() from public, anon, authenticated;
revoke all on function public.send_client_artist_delivery_reminders() from public, anon, authenticated;
revoke all on function public.run_artist_delivery_reminder_sweep() from public, anon, authenticated;
grant execute on function public.run_artist_delivery_reminder_sweep() to service_role;

create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  perform cron.unschedule('send-artist-delivery-reminders');
exception when others then
  null; -- job didn't exist yet -- fine on a first run.
end $$;

-- Once a day, 09:00 UTC -- same cadence as the accept-by reminders. Both
-- sweep functions are idempotent per day via the user_notifications lookup.
select cron.schedule(
  'send-artist-delivery-reminders',
  '0 9 * * *',
  $$select public.run_artist_delivery_reminder_sweep();$$
);

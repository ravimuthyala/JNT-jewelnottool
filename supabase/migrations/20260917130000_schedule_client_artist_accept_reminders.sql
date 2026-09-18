-- Artist-accept reminder for client_custom_requests (a client's own direct
-- request straight to an artist, no brand involved) -- the counterpart to
-- 20260916150000's brand-request version, but this request shape has no
-- request_accept_by concept at all: expire_overdue_client_requests
-- (20260911140000) already treats need_by + 1 day as the artist's hard
-- accept deadline for this table. So the reminder window here is simply
-- need_by - 6 days through need_by, once a day, for as long as the artist
-- hasn't accepted or declined.
--
-- Scope, deliberately: only the direct/specific-artist case (is_direct_request
-- = true, selected_artist_email set), same reasoning as the brand-side
-- reminders -- an artist-pool request has no single recipient to remind.
--
-- Queues an SMS (public.resolve_contact_phone, 20260916135000) alongside
-- the in-app user_notifications row, drained by send-queued-sms
-- (20260917120000) -- stays SIMULATED until Twilio secrets are deployed;
-- see that function's own header comment.
create or replace function public.send_client_artist_accept_reminders()
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
  days_left int;
  need_by_display text;
  body_text text;
  sms_text text;
  phone text;
begin
  for r in
    select *
    from public.client_custom_requests
    where status not in ('expired', 'cancelled', 'canceled', 'declined', 'delivered', 'shipped', 'completed')
      and coalesce(is_direct_request, false) = true
      and coalesce(selected_artist_email, '') <> ''
      and coalesce(accepted_by_artist_email, '') = ''
      and coalesce(lower(artist_status), '') not like '%declin%'
      and coalesce(lower(direct_artist_status), '') not like '%declin%'
      and not (
        coalesce(declined_by_artist_emails, '[]'::jsonb) ? lower(trim(selected_artist_email))
      )
      and need_by is not null
      and now()::date between (need_by::date - interval '6 days')::date
        and need_by::date
      and not exists (
        select 1 from public.user_notifications n
        where n.order_id = r.id::text
          and n.type = 'client_artist_accept_reminder'
          and n.created_at::date = now()::date
      )
  loop
    display_campaign := coalesce(nullif(r.campaign_name, ''), nullif(r.title, ''), 'Request');
    display_order := coalesce(nullif(r.order_number, ''), nullif(r.request_number, ''), r.id::text);
    display_client := coalesce(nullif(r.client_name, ''), 'a client');
    days_left := greatest(0, (r.need_by::date - now()::date));
    need_by_display := coalesce(
      nullif(r.need_by_display, ''),
      to_char(r.need_by::date, 'MM/DD/YYYY')
    );

    body_text := format(
      'Your %s request %s from %s needs to be accepted by %s.',
      display_campaign, display_order, display_client, need_by_display
    );

    insert into public.user_notifications
      (receiver_email, title, body, type, order_id, order_number, source_collection, read, extra, created_at, updated_at)
    values
      (lower(trim(r.selected_artist_email)), 'Reminder: Action needed', body_text,
       'client_artist_accept_reminder', r.id::text, coalesce(r.order_number, ''),
       'Client_Custom_Requests', false,
       jsonb_build_object('daysLeft', days_left, 'acceptBy', need_by_display), now(), now());

    phone := public.resolve_contact_phone(r.selected_artist_email);
    if phone is not null then
      sms_text := format(
        'JNT: Your %s request %s from %s needs to be accepted by %s.',
        display_campaign, display_order, display_client, need_by_display
      );
      insert into public.sms_outbox (to_number, message, status, created_at)
      values (phone, sms_text, 'queued', now());
    end if;
  end loop;
end;
$function$;

revoke all on function public.send_client_artist_accept_reminders() from public, anon, authenticated;
grant execute on function public.send_client_artist_accept_reminders() to service_role;

create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  perform cron.unschedule('send-client-artist-accept-reminders');
exception when others then
  null; -- job didn't exist yet -- fine on a first run.
end $$;

-- Same cadence as the other reminder jobs -- once a day, 09:00 UTC. The
-- function is idempotent per day via the user_notifications lookup above.
select cron.schedule(
  'send-client-artist-accept-reminders',
  '0 9 * * *',
  $$select public.send_client_artist_accept_reminders();$$
);

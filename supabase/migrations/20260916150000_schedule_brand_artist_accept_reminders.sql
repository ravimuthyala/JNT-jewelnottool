-- Artist-side counterpart to 20260914120000_schedule_brand_client_accept_reminders.sql.
-- Brand requests sent directly to a specific artist (is_direct_request = true,
-- selected_artist_email set -- this pool also includes users registered under
-- the client_artist role, since brand_custom_request_page.dart's artist
-- picker queries both the artist and client_artist tables) get a daily
-- reminder to accept, once a day, for as long as the artist hasn't accepted
-- or declined.
--
-- Timing: need_by - 5 days through need_by, NOT request_accept_by like the
-- client-side reminder -- "the artist comes in once the client accepts"
-- (mirrors has_client_accepted in expire_overdue_company_requests,
-- 20260911140000, which already treats need_by, not request_accept_by, as
-- the artist's real deadline once a client has accepted). This replaces an
-- earlier version of this same function that used request_accept_by
-- (submission + 2 days); that timing didn't hold up once need_by is far out
-- -- an artist could still be well within their real window when the
-- request_accept_by clock ran out. This function's own has_client_accepted
-- gate below skips any row where the client hasn't accepted yet, since
-- before that point there's nothing for the artist to act on regardless of
-- need_by.
--
-- Also now queues an SMS (public.resolve_contact_phone, 20260916135000)
-- alongside the in-app user_notifications row, drained by send-queued-sms
-- (20260917120000) -- stays SIMULATED until Twilio secrets are deployed;
-- see that function's own header comment.
--
-- Scope, deliberately: only the direct/specific-artist case (mirrors the
-- client migration's own direct-only scope). An artist POOL request
-- (open_to_artist_pool = true, no single selected_artist_email) has no
-- single recipient to remind.
create or replace function public.send_brand_artist_accept_reminders()
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
  days_left int;
  need_by_display text;
  body_text text;
  sms_text text;
  phone text;
begin
  for r in
    select *
    from public.company_custom_requests
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
      and now()::date between (need_by::date - interval '5 days')::date
        and need_by::date
      and not exists (
        select 1 from public.user_notifications n
        where n.order_id = r.id::text
          and n.type = 'brand_artist_accept_reminder'
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
    days_left := greatest(0, (r.need_by::date - now()::date));
    need_by_display := to_char(r.need_by::date, 'MM/DD/YYYY');

    body_text := format(
      'Your %s %s brand request %s needs to be accepted by %s.',
      display_brand, display_campaign, display_order, need_by_display
    );

    insert into public.user_notifications
      (receiver_email, title, body, type, order_id, order_number, source_collection, read, extra, created_at, updated_at)
    values
      (lower(trim(r.selected_artist_email)), 'Reminder: Action needed', body_text,
       'brand_artist_accept_reminder', r.id::text, coalesce(r.order_number, ''),
       'Company_Custom_Requests', false,
       jsonb_build_object('daysLeft', days_left, 'acceptBy', need_by_display), now(), now());

    phone := public.resolve_contact_phone(r.selected_artist_email);
    if phone is not null then
      sms_text := format(
        'JNT: Your %s brand request %s needs to be accepted by %s.',
        display_brand, display_order, need_by_display
      );
      insert into public.sms_outbox (to_number, message, status, created_at)
      values (phone, sms_text, 'queued', now());
    end if;
  end loop;
end;
$function$;

revoke all on function public.send_brand_artist_accept_reminders() from public, anon, authenticated;
grant execute on function public.send_brand_artist_accept_reminders() to service_role;

create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  perform cron.unschedule('send-brand-artist-accept-reminders');
exception when others then
  null; -- job didn't exist yet -- fine on a first run.
end $$;

-- Same cadence as the client reminder job -- once a day, 09:00 UTC. The
-- function is idempotent per day via the user_notifications lookup above.
select cron.schedule(
  'send-brand-artist-accept-reminders',
  '0 9 * * *',
  $$select public.send_brand_artist_accept_reminders();$$
);

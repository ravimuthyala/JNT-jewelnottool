-- The daily "accept the request" reminder (20260914120000) told the client
-- how many days were left but never stated the actual accept-by date. Now
-- that request_accept_by is set to submission date + 2 days (see
-- brand_custom_request_page.dart), spell the deadline date out in the
-- message itself rather than just a relative day-count.
--
-- Also now queues an SMS (public.resolve_contact_phone, 20260916135000)
-- alongside the existing in-app user_notifications row, drained by
-- send-queued-sms (20260917120000) -- stays SIMULATED (no real text sent)
-- until Twilio secrets are deployed on that function; see its own header
-- comment.
create or replace function public.send_brand_client_accept_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  r record;
  display_brand text;
  display_campaign text;
  display_order text;
  days_left int;
  accept_by_display text;
  body_text text;
  sms_text text;
  phone text;
begin
  for r in
    select *
    from public.company_custom_requests
    where status not in ('expired', 'cancelled', 'canceled', 'declined', 'delivered', 'shipped', 'completed')
      and coalesce(open_to_client_pool, false) = false
      and coalesce(selected_client_email, '') <> ''
      and coalesce(accepted_by_client_email, '') = ''
      and coalesce(lower(client_status), '') not like '%declin%'
      and request_accept_by is not null
      and now()::date between (request_accept_by::date - interval '2 days')::date
        and request_accept_by::date
      and not exists (
        select 1 from public.user_notifications n
        where n.order_id = r.id::text
          and n.type = 'brand_client_accept_reminder'
          and n.created_at::date = now()::date
      )
  loop
    display_brand := coalesce(nullif(r.brand_name, ''), nullif(r.company_name, ''), 'Brand Company');
    display_campaign := coalesce(nullif(r.campaign_name, ''), nullif(r.title, ''), 'Campaign');
    display_order := coalesce(nullif(r.order_number, ''), r.id::text);
    days_left := greatest(0, (r.request_accept_by::date - now()::date));
    accept_by_display := coalesce(
      nullif(r.request_accept_by_display, ''),
      to_char(r.request_accept_by::date, 'MM/DD/YYYY')
    );

    body_text := format(
      'Your %s %s brand request %s needs to be accepted by %s.',
      display_brand, display_campaign, display_order, accept_by_display
    );

    insert into public.user_notifications
      (receiver_email, title, body, type, order_id, order_number, source_collection, read, extra, created_at, updated_at)
    values
      (lower(trim(r.selected_client_email)), 'Reminder: Action needed', body_text,
       'brand_client_accept_reminder', r.id::text, coalesce(r.order_number, ''),
       'Company_Custom_Requests', false,
       jsonb_build_object('daysLeft', days_left, 'acceptBy', accept_by_display), now(), now());

    phone := public.resolve_contact_phone(r.selected_client_email);
    if phone is not null then
      sms_text := format(
        'JNT: Your %s brand request %s needs to be accepted by %s.',
        display_brand, display_order, accept_by_display
      );
      insert into public.sms_outbox (to_number, message, status, created_at)
      values (phone, sms_text, 'queued', now());
    end if;
  end loop;
end;
$function$;

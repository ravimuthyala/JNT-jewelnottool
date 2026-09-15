-- Automates the "remind the client to accept" step for brand requests. The
-- admin app's Send Reminder link (see brand_requests_page.dart) already lets
-- an admin trigger this manually at any time; this adds the requested
-- automatic cadence on top of it: starting 2 days before the request's
-- accept-by deadline, and once a day (not every cron tick) up to and
-- including the deadline day, for as long as the request is still waiting
-- on a specific client to accept.
--
-- Scope, deliberately: only the "specific (direct) client" case --
-- open_to_client_pool = false and selected_client_email set. A pool has no
-- single recipient (matches the manual Send Reminder's own scope), and a
-- named GROUP of clients (selected_group_client_emails) needs per-member
-- accepted/declined state that only exists today inside Dart's
-- buildGroupClientEntries() (it reads from several possible nested jsonb
-- shapes -- groupOrder.clients / .selectedClients / .groupMembers /
-- .participants / .groupOrderClients / .clientsData, whichever a given
-- request actually used) -- re-deriving that fuzzy matching in SQL risks
-- silently diverging from what the admin UI shows. Same reasoning the
-- 20260911140000 expiry sweep migration already used to justify not
-- replicating Dart's full brand-recipient resolution. Group reminders can
-- be added later as its own pass once/if that's needed.
--
-- "Has the client declined" is checked via the client_status column rather
-- than brand_requests_page.dart's full isClientDeclined derivation (which
-- also matches free-text status-reason strings and several jsonb fallback
-- fields) -- same simplification tradeoff as above.

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
  body_text text;
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

    body_text := case
      when days_left <= 0 then
        format('Your %s %s brand request %s needs your acceptance today.', display_brand, display_campaign, display_order)
      when days_left = 1 then
        format('Your %s %s brand request %s needs your acceptance by tomorrow.', display_brand, display_campaign, display_order)
      else
        format('Your %s %s brand request %s needs your acceptance within %s days.', display_brand, display_campaign, display_order, days_left)
    end;

    insert into public.user_notifications
      (receiver_email, title, body, type, order_id, order_number, source_collection, read, extra, created_at, updated_at)
    values
      (lower(trim(r.selected_client_email)), 'Reminder: Action needed', body_text,
       'brand_client_accept_reminder', r.id::text, coalesce(r.order_number, ''),
       'Company_Custom_Requests', false, jsonb_build_object('daysLeft', days_left), now(), now());
  end loop;
end;
$function$;

revoke all on function public.send_brand_client_accept_reminders() from public, anon, authenticated;
grant execute on function public.send_brand_client_accept_reminders() to service_role;

create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  perform cron.unschedule('send-brand-client-accept-reminders');
exception when others then
  null; -- job didn't exist yet -- fine on a first run.
end $$;

-- Once a day (09:00 UTC) -- the function itself is also idempotent per day
-- via the user_notifications lookup above, so a manual re-run or a missed
-- tick can't double-send.
select cron.schedule(
  'send-brand-client-accept-reminders',
  '0 9 * * *',
  $$select public.send_brand_client_accept_reminders();$$
);

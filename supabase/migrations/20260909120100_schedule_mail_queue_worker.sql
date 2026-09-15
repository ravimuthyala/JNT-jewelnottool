-- Schedules the send-queued-emails edge function to run every 2 minutes,
-- draining any 'queued' rows in public.mail_queue (order-shipped/delivered
-- emails, ambassador-payout emails). Before this migration, nothing ever
-- consumed that table -- see 20260824090000_add_queue_client_email_rpc.sql
-- for how that gap was found.
--
-- REQUIRES ONE-TIME MANUAL SETUP before this job can authenticate to the
-- edge function -- run ONCE in this project's SQL editor (never commit the
-- actual key to a migration file, which is why it isn't done here):
--
--   select vault.create_secret(
--     '<this project''s service_role key, from Project Settings > API>',
--     'service_role_key'
--   );
--
-- The edge function itself is deployed with the platform default
-- verify_jwt = true, so this Vault-stored service role key is what lets
-- pg_cron's request pass that check -- it's never written into this file.
--
-- NOTE: the function URL below is project-specific (this one is
-- <project-ref>.functions.supabase.co). Applying this same migration to a
-- different Supabase project (e.g. moving from UAT to Production) requires
-- swapping in that project's own ref first.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
begin
  perform cron.unschedule('drain-mail-queue');
exception when others then
  null; -- job didn't exist yet -- fine on a first run.
end $$;

select cron.schedule(
  'drain-mail-queue',
  '*/2 * * * *',
  $$
  select net.http_post(
    url := 'https://gonutknapmzhrzvvrfka.functions.supabase.co/send-queued-emails',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'service_role_key'
        limit 1
      )
    ),
    body := '{}'::jsonb
  );
  $$
);

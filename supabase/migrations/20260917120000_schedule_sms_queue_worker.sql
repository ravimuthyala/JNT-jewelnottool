-- Schedules the send-queued-sms edge function to run every 2 minutes,
-- draining any 'queued' rows in public.sms_outbox -- same shape as
-- 20260909120100_schedule_mail_queue_worker.sql for mail_queue. Before this,
-- sms_outbox had rows written by NotificationsService.queueSms() (and, as
-- of this migration, the reminder functions below) but nothing ever
-- consumed them.
--
-- Reuses the same Vault secret ('service_role_key') that
-- 20260909120100_schedule_mail_queue_worker.sql already required a one-time
-- manual setup for -- no additional Vault setup needed if that migration is
-- already applied to this project. If it isn't, run once in this project's
-- SQL editor first:
--
--   select vault.create_secret(
--     '<this project''s service_role key, from Project Settings > API>',
--     'service_role_key'
--   );
--
-- NOTE: the function URL below is project-specific (this one is
-- <project-ref>.functions.supabase.co). Applying this same migration to a
-- different Supabase project (e.g. moving from UAT to Production) requires
-- swapping in that project's own ref first.
--
-- send-queued-sms itself stays in SIMULATED mode (writes to console, marks
-- rows 'simulated' rather than actually texting anyone) until
-- TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN / TWILIO_FROM_NUMBER are deployed
-- as Edge Function secrets -- see that function's own header comment. This
-- cron job can be scheduled now regardless; it's a no-op on real delivery
-- until those secrets are set.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
begin
  perform cron.unschedule('drain-sms-queue');
exception when others then
  null; -- job didn't exist yet -- fine on a first run.
end $$;

select cron.schedule(
  'drain-sms-queue',
  '*/2 * * * *',
  $$
  select net.http_post(
    url := 'https://gonutknapmzhrzvvrfka.functions.supabase.co/send-queued-sms',
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

-- mail_queue previously had no way to record WHY a send failed, which is
-- exactly the kind of silent-failure gap that let shipped/delivered emails
-- go unnoticed for so long (see 20260824090000_add_queue_client_email_rpc.sql
-- for that history). The send-queued-emails edge function
-- (supabase/functions/send-queued-emails) writes the error message here
-- whenever it marks a row 'failed', so a stuck queue is debuggable from the
-- table itself instead of only from function logs.
alter table public.mail_queue
  add column if not exists last_error text;

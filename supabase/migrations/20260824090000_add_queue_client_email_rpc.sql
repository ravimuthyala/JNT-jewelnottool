-- NotificationsService.queueEmail (lib/services/notifications_service.dart)
-- inserts into mail_queue directly from the client session -- confirmed
-- empty in production despite shipped/delivered emails "succeeding" with
-- no error, because .insert() from a client session silently no-ops
-- under RLS (the same class of bug fixed for artist review ratings in
-- migration 20260801002432_add_apply_client_review_to_artist_rpc.sql).
-- The one place mail_queue is written today, notify_client_ambassador_
-- payout_setup() in 20260724090000_add_client_ambassador_payout.sql, only
-- works because it's a SECURITY DEFINER trigger, not a client insert.
--
-- This function runs as SECURITY DEFINER so a signed-in client/artist can
-- queue an email for any recipient (order emails go to the client, not the
-- sender) without needing broad INSERT access to mail_queue.
create or replace function public.queue_client_email(
  p_to_email text,
  p_subject text,
  p_text text,
  p_html text default null,
  p_preheader text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text := lower(trim(p_to_email));
begin
  if normalized_email = '' or normalized_email not like '%@%' then
    raise exception 'queue_client_email: invalid recipient %', p_to_email;
  end if;

  insert into public.mail_queue (
    to_email,
    to_list,
    subject,
    text,
    html,
    status,
    created_at,
    payload
  ) values (
    normalized_email,
    jsonb_build_array(normalized_email),
    p_subject,
    p_text,
    nullif(trim(coalesce(p_html, '')), ''),
    'queued',
    now(),
    jsonb_build_object(
      'to', jsonb_build_array(normalized_email),
      'message', jsonb_build_object(
        'subject', p_subject,
        'text', p_text,
        'html', nullif(trim(coalesce(p_html, '')), ''),
        'preheader', nullif(trim(coalesce(p_preheader, '')), '')
      )
    )
  );
end;
$$;

-- Only signed-in clients/artists queue emails (order shipped/delivered
-- notifications), so this never needs to be callable anonymously.
grant execute on function public.queue_client_email(text, text, text, text, text) to authenticated;

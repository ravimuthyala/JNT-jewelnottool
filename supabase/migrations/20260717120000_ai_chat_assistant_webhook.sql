-- JNT AI Assistant: server-side auto-reply for the "ai.chatbot@jnt.com" chat
-- thread. On INSERT into request_chat_messages, if the message is addressed
-- to the assistant (and not sent by the assistant itself, to avoid a reply
-- loop), calls the "ai-chat-assistant" Edge Function via pg_net, which
-- inserts a rule-based reply back into the same conversation.
--
-- After applying this migration to a project, you must additionally set two
-- database settings (per project — run once in the SQL editor):
--
--   alter database postgres set app.settings.ai_chat_assistant_url =
--     'https://<project-ref>.supabase.co/functions/v1/ai-chat-assistant';
--   alter database postgres set app.settings.ai_chat_assistant_secret =
--     '<same value as the AI_ASSISTANT_WEBHOOK_SECRET function secret>';
--
-- and deploy the function itself:
--   supabase functions deploy ai-chat-assistant --project-ref <project-ref>
--   supabase secrets set AI_ASSISTANT_WEBHOOK_SECRET=<random-string> --project-ref <project-ref>
--
-- Until those settings are configured, the trigger is a harmless no-op
-- (function_url resolves empty and the trigger returns early).

create extension if not exists pg_net with schema extensions;

create or replace function public.ai_chat_assistant_dispatch()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  function_url text;
  webhook_secret text;
begin
  function_url := current_setting('app.settings.ai_chat_assistant_url', true);
  webhook_secret := current_setting('app.settings.ai_chat_assistant_secret', true);

  if function_url is null or function_url = '' then
    -- Not configured yet for this project/environment; skip silently so the
    -- migration is safe to apply before the function is deployed.
    return new;
  end if;

  perform net.http_post(
    url := function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', coalesce(webhook_secret, '')
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'request_chat_messages',
      'record', to_jsonb(new)
    )
  );

  return new;
end;
$$;

drop trigger if exists ai_chat_assistant_on_message on public.request_chat_messages;

create trigger ai_chat_assistant_on_message
after insert on public.request_chat_messages
for each row
-- Only messages addressed to the AI assistant, and never messages sent by
-- the assistant itself (would otherwise trigger an infinite reply loop).
when (
  new.artist_email = 'ai.chatbot@jnt.com'
  and coalesce(new.sender_email, '') <> 'ai.chatbot@jnt.com'
)
execute function public.ai_chat_assistant_dispatch();

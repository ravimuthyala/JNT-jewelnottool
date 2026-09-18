-- Removes the JNT AI Assistant feature (20260717120000_ai_chat_assistant_webhook.sql).
-- The app no longer routes any chat to ai.chatbot@jnt.com -- brand-request
-- chat now goes directly between client and artist, same as every other
-- request type (see lib/pages/order_details_pages.dart and
-- lib/pages/artist_accepted_request_sheet.dart). This drops the server-side
-- half: the trigger that dispatched to the ai-chat-assistant Edge Function
-- (itself deleted -- supabase/functions/ai-chat-assistant/) and the
-- function it called. Existing ai.chatbot@jnt.com conversation rows in
-- request_chats/request_chat_messages are left in place as history, not
-- deleted -- they're just inert now, since nothing addresses new messages
-- to that email going forward.
drop trigger if exists ai_chat_assistant_on_message on public.request_chat_messages;
drop function if exists public.ai_chat_assistant_dispatch();

-- The two database settings the original migration had you set per-project
-- (app.settings.ai_chat_assistant_url / _secret) are harmless to leave
-- configured -- nothing reads them anymore now that the trigger is gone --
-- but can be cleared too if you want a clean slate:
--   alter database postgres reset app.settings.ai_chat_assistant_url;
--   alter database postgres reset app.settings.ai_chat_assistant_secret;
-- Not run automatically here since ALTER DATABASE ... RESET requires
-- superuser in some Supabase project configurations and isn't safe to
-- assume from a migration.

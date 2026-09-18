-- Shared helper for the reminder functions (20260916140000 onward) that now
-- also queue an SMS -- keeps this lookup in one place instead of
-- duplicating the same three-table join in every reminder function. Must
-- stay ordered before any migration that calls it. Looks up panel_phone by
-- email across all three profile tables
-- a request's client/artist recipient could be registered under -- a
-- client_artist row can be the match for either a "client" or an "artist"
-- recipient, same as brand_custom_request_page.dart's own recipient pickers
-- (see 20260916150000's header comment).
create or replace function public.resolve_contact_phone(p_email text)
returns text
language sql
stable
security definer
set search_path = public
as $function$
  select nullif(trim(m.panel_phone), '')
  from (
    select panel_phone from public.artist where lower(trim(email)) = lower(trim(p_email))
    union all
    select panel_phone from public.client_artist where lower(trim(email)) = lower(trim(p_email))
    union all
    select panel_phone from public.client where lower(trim(email)) = lower(trim(p_email))
  ) m
  where nullif(trim(m.panel_phone), '') is not null
  limit 1;
$function$;

revoke all on function public.resolve_contact_phone(text) from public, anon, authenticated;
grant execute on function public.resolve_contact_phone(text) to service_role;

-- Session restore and post-login role lookup (login_page.dart's
-- _loadAccountDoc) queried client_artist/artist/client/company individually
-- via 4 separate parallel REST requests to find which table the signed-in
-- user's row lives in. Logged from a real device: each of those 4 requests
-- took 1.8s-4.7s on its own (TLS handshake + JWT/RLS evaluation + Postgrest
-- overhead per request), so total wait tracked the slowest one -- adding
-- several seconds to every cold start and every login submit.
--
-- This function does the same 4-table check server-side in a single round
-- trip. SECURITY DEFINER so it can check all four tables regardless of the
-- caller's session, but it only ever returns the row belonging to the
-- caller's own uid (auth.uid()), so it doesn't expose anything the caller
-- couldn't already read about themselves under RLS.
create or replace function public.resolve_account_row_for_uid()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_uid uuid := auth.uid();
  found_row jsonb;
begin
  if caller_uid is null then
    return null;
  end if;

  select to_jsonb(t) into found_row from public.client_artist t where t.id = caller_uid limit 1;
  if found_row is not null then
    return found_row || jsonb_build_object('_table', 'client_artist');
  end if;

  select to_jsonb(t) into found_row from public.artist t where t.id = caller_uid limit 1;
  if found_row is not null then
    return found_row || jsonb_build_object('_table', 'artist');
  end if;

  select to_jsonb(t) into found_row from public.client t where t.id = caller_uid limit 1;
  if found_row is not null then
    return found_row || jsonb_build_object('_table', 'client');
  end if;

  select to_jsonb(t) into found_row from public.company t where t.id = caller_uid limit 1;
  if found_row is not null then
    return found_row || jsonb_build_object('_table', 'company');
  end if;

  return null;
end;
$$;

-- Only meaningful for a signed-in caller (it keys off auth.uid()), so no
-- need for anon access.
grant execute on function public.resolve_account_row_for_uid() to authenticated;

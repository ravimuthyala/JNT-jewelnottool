-- Registration's "this email is already registered" check queries the
-- client/artist/company/client_artist tables directly, which silently
-- returns no rows under RLS: client/client_artist only allow reading your
-- own row (auth.uid() = id), and artist/company require an authenticated
-- session at all, which registration typically doesn't have yet. The check
-- has therefore never been able to detect a genuine duplicate.
--
-- This function runs as SECURITY DEFINER so it can check across all four
-- tables regardless of the caller's session, but it only ever returns a
-- role name (or null) -- never row contents -- so it doesn't expose
-- anything beyond "is this email already used, and under which role".
create or replace function public.find_existing_role_for_email(p_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized text := lower(trim(p_email));
begin
  if normalized = '' or normalized not like '%@%' then
    return null;
  end if;

  if exists (select 1 from public.client where lower(email) = normalized limit 1) then
    return 'client';
  end if;

  if exists (select 1 from public.artist where lower(email) = normalized limit 1) then
    return 'artist';
  end if;

  if exists (select 1 from public.company where lower(email) = normalized limit 1) then
    return 'company';
  end if;

  if exists (select 1 from public.client_artist where lower(email) = normalized limit 1) then
    return 'client_artist';
  end if;

  return null;
end;
$$;

-- Callable pre-signup (anon) and post-signup (authenticated) -- safe since
-- the function never returns row data, only a role name.
grant execute on function public.find_existing_role_for_email(text) to anon, authenticated;

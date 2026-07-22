-- The Brand Custom Request page's "Designate a specific client", "Group
-- Client", and "Request a specific artist" dropdowns fetch candidate rows
-- directly from client/artist/client_artist to run existing client-side
-- eligibility filters (brand-partner status, NFC eligibility, Goldsmith/
-- Crowned artist tier -- see isBrandPartnerClient/isEligibleBrandRequestArtist
-- in lib/pages/brand_custom_request_page.dart). Under RLS this silently
-- returns nothing for `client` (SELECT is restricted to auth.uid() = id,
-- i.e. your own row only -- there is no "read other users' client rows"
-- policy at all), which is why those two dropdowns show no eligible
-- clients. `artist`/`client_artist` already have a "some authenticated user
-- can read all rows" policy, so they aren't blocked the same way, but this
-- routes them through the same safe path for consistency.
--
-- This function runs as SECURITY DEFINER so it can bypass that per-row
-- restriction, but only for authenticated callers who are themselves a
-- brand/company account (checked against auth.uid() against public.company)
-- -- an ordinary client or artist account cannot use this to read other
-- clients' full profile rows. The Dart-side eligibility filtering is
-- unchanged; this only fixes the underlying row fetch that was silently
-- returning nothing.
create or replace function public.fetch_role_rows_for_brand_outreach(
  p_table text,
  p_limit integer default 300
)
returns setof jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  -- Matches the id-OR-email fallback already used by this project's own
  -- RLS policies (e.g. "users can read own client profile"), since not
  -- every company row is guaranteed to have id = auth.uid() (older/seeded
  -- accounts in particular).
  if not exists (
    select 1 from public.company
    where id = auth.uid()
       or (caller_email <> '' and lower(email) = caller_email)
  ) then
    raise exception 'not authorized: caller is not a brand/company account';
  end if;

  if p_table = 'client' then
    return query select to_jsonb(t) from public.client t limit p_limit;
  elsif p_table = 'artist' then
    return query select to_jsonb(t) from public.artist t limit p_limit;
  elsif p_table = 'client_artist' then
    return query select to_jsonb(t) from public.client_artist t limit p_limit;
  else
    raise exception 'unsupported table: %', p_table;
  end if;
end;
$$;

grant execute on function public.fetch_role_rows_for_brand_outreach(text, integer) to authenticated;

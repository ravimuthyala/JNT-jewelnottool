alter table public.company
  add column if not exists payout jsonb default '{}'::jsonb,
  add column if not exists panel_payout jsonb default '{}'::jsonb,
  add column if not exists panel_payout_method text,
  add column if not exists panel_payout_legal_name text,
  add column if not exists panel_payout_email text;

update public.company
set
  payout = case
    when coalesce(payout, '{}'::jsonb) = '{}'::jsonb
      then coalesce(panel_payout, '{}'::jsonb)
    else payout
  end,
  panel_payout = case
    when coalesce(panel_payout, '{}'::jsonb) = '{}'::jsonb
      then coalesce(payout, '{}'::jsonb)
    else panel_payout
  end,
  panel_payout_method = coalesce(
    nullif(panel_payout_method, ''),
    nullif(panel_payout->>'method', ''),
    nullif(payout->>'method', '')
  ),
  panel_payout_email = coalesce(
    nullif(panel_payout_email, ''),
    nullif(panel_payout->>'email', ''),
    nullif(payout->>'email', ''),
    nullif(panel_payout->'paypal'->>'email', ''),
    nullif(payout->'paypal'->>'email', ''),
    nullif(panel_payout->'venmo'->>'username', ''),
    nullif(payout->'venmo'->>'username', '')
  ),
  panel_payout_legal_name = coalesce(
    nullif(panel_payout_legal_name, ''),
    nullif(panel_payout->>'accountHolder', ''),
    nullif(payout->>'accountHolder', ''),
    nullif(panel_payout->'ach'->>'accountHolder', ''),
    nullif(payout->'ach'->>'accountHolder', ''),
    nullif(panel_payout->'ach'->>'accountHolderName', ''),
    nullif(payout->'ach'->>'accountHolderName', '')
  ),
  updated_at = now()
where
  payout is null
  or panel_payout is null
  or panel_payout_method is null
  or panel_payout_email is null
  or panel_payout_legal_name is null
  or payout = '{}'::jsonb
  or panel_payout = '{}'::jsonb;

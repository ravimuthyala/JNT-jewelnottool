-- NFC chip lifecycle table: each physical NFC chip a client activates gets its
-- own row here. The chip's NDEF record carries a stable resolver URL
-- (https://www.jntnails.com/n/{id}) instead of a raw destination, so changing
-- what's active -- or deactivating a lost/damaged chip -- is a DB write with
-- no need to re-tap and rewrite the physical chip.

create table if not exists public.nfc_chips (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  owner_table text not null check (owner_table in ('client', 'client_artist')),
  label text,
  status text not null default 'active'
    check (status in ('active', 'deactivated_lost', 'deactivated_damaged', 'replaced')),
  active_item_key text,
  active_item_type text,
  active_item_value text,
  nfc_tag_uid text,
  activated_at timestamptz,
  deactivated_at timestamptz,
  deactivated_reason text check (deactivated_reason in ('lost', 'damaged') or deactivated_reason is null),
  deactivated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- An owner can have several simultaneously-active chips (one per nail/finger),
-- each independently switchable -- deliberately not unique-constrained.
create index if not exists nfc_chips_owner_id_idx on public.nfc_chips (owner_id);

alter table public.nfc_chips enable row level security;

create policy "nfc_chips read own row" on public.nfc_chips
  for select using (auth.uid() = owner_id);

create policy "nfc_chips insert own row" on public.nfc_chips
  for insert with check (auth.uid() = owner_id);

create policy "nfc_chips update own row" on public.nfc_chips
  for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

-- Matches the existing admin-bypass pattern used elsewhere in this schema
-- (see e.g. "admins update client rows" on public.client).
create policy "admins update nfc chips" on public.nfc_chips
  for update using (exists (
    select 1 from public.admin_users a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and a.is_active = true
  )) with check (exists (
    select 1 from public.admin_users a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and a.is_active = true
  ));

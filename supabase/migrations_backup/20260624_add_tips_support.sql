create extension if not exists pgcrypto;

create table if not exists public.tips (
  id uuid primary key default gen_random_uuid(),
  order_id text not null,
  artist_id text not null,
  created_by_uid uuid not null default auth.uid(),
  tip_percent integer not null,
  tip_amount numeric(12,2) not null default 0,
  status text not null default 'pending_payment',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  data jsonb not null default '{}'::jsonb
);

alter table public.client_custom_requests
  add column if not exists tip jsonb not null default '{}'::jsonb;

alter table public.company_custom_requests
  add column if not exists tip jsonb not null default '{}'::jsonb;

alter table public.tips enable row level security;

drop policy if exists tips_select_own_or_assigned_artist on public.tips;
create policy tips_select_own_or_assigned_artist
on public.tips
for select
to authenticated
using (
  auth.uid() is not null
  and (
    created_by_uid = auth.uid()
    or artist_id = auth.uid()::text
  )
);

drop policy if exists tips_insert_authenticated on public.tips;
create policy tips_insert_authenticated
on public.tips
for insert
to authenticated
with check (
  auth.uid() is not null
  and created_by_uid = auth.uid()
);

create index if not exists tips_order_id_idx on public.tips (order_id);
create index if not exists tips_artist_id_idx on public.tips (artist_id);
create index if not exists tips_created_by_uid_idx on public.tips (created_by_uid);
create index if not exists tips_created_at_idx on public.tips (created_at desc);

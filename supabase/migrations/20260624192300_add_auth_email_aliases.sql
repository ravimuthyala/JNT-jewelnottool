create table if not exists public.auth_email_aliases (
  login_email text primary key,
  auth_email text not null,
  uid text not null,
  updated_at timestamptz not null default now()
);

alter table public.auth_email_aliases enable row level security;

drop policy if exists auth_email_aliases_select_public on public.auth_email_aliases;
create policy auth_email_aliases_select_public
on public.auth_email_aliases
for select
to anon, authenticated
using (true);

drop policy if exists auth_email_aliases_insert_own on public.auth_email_aliases;
create policy auth_email_aliases_insert_own
on public.auth_email_aliases
for insert
to authenticated
with check (uid = auth.uid()::text);

drop policy if exists auth_email_aliases_update_own on public.auth_email_aliases;
create policy auth_email_aliases_update_own
on public.auth_email_aliases
for update
to authenticated
using (uid = auth.uid()::text)
with check (uid = auth.uid()::text);

create index if not exists auth_email_aliases_auth_email_idx on public.auth_email_aliases (auth_email);
create index if not exists auth_email_aliases_uid_idx on public.auth_email_aliases (uid);

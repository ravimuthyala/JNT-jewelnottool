alter table public.client
  add column if not exists payout jsonb default '{}'::jsonb not null;

comment on column public.client.payout is
  'Payout method used by Ambassador-tier clients for brand campaign earnings.';

create or replace function public.notify_client_ambassador_payout_setup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_tier text;
  old_tier text;
  normalized_email text;
begin
  new_tier := lower(coalesce(
    new.ascension->>'status',
    new.ascension->>'tier',
    new.ascension->>'levelName',
    new.profile->>'status',
    new.profile->>'tier',
    new.basic->>'status',
    new.basic->>'tier',
    new.client->>'status',
    new.client->>'tier',
    ''
  ));
  old_tier := lower(coalesce(
    old.ascension->>'status',
    old.ascension->>'tier',
    old.ascension->>'levelName',
    old.profile->>'status',
    old.profile->>'tier',
    old.basic->>'status',
    old.basic->>'tier',
    old.client->>'status',
    old.client->>'tier',
    ''
  ));
  normalized_email := lower(trim(coalesce(new.email, new.panel_email, '')));

  if new_tier = 'ambassador'
     and old_tier is distinct from 'ambassador'
     and normalized_email <> '' then
    if not exists (
      select 1
      from public.user_notifications
      where receiver_email = normalized_email
        and type = 'ambassador_payout_setup_required'
    ) then
      insert into public.user_notifications (
        receiver_email,
        title,
        body,
        type,
        source_collection,
        read,
        extra,
        created_at_millis
      ) values (
        normalized_email,
        'Payout method required',
        'Please update your payout method in your profile.',
        'ambassador_payout_setup_required',
        'client',
        false,
        jsonb_build_object('destination', 'client_profile_payout'),
        (extract(epoch from clock_timestamp()) * 1000)::bigint
      );

      insert into public.mail_queue (
        to_email,
        to_list,
        subject,
        text,
        status,
        payload
      ) values (
        normalized_email,
        jsonb_build_array(normalized_email),
        'Update your payout method',
        'Please update your payout method in your profile to receive payouts for Brand Campaign requests.',
        'queued',
        jsonb_build_object(
          'to', jsonb_build_array(normalized_email),
          'message', jsonb_build_object(
            'subject', 'Update your payout method',
            'text', 'Please update your payout method in your profile to receive payouts for Brand Campaign requests.'
          )
        )
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists client_ambassador_payout_setup_trigger
  on public.client;

create trigger client_ambassador_payout_setup_trigger
after update of ascension, profile, basic, client on public.client
for each row
execute function public.notify_client_ambassador_payout_setup();

drop trigger if exists client_artist_ambassador_payout_setup_trigger
  on public.client_artist;

create trigger client_artist_ambassador_payout_setup_trigger
after update of ascension, profile, basic, client on public.client_artist
for each row
execute function public.notify_client_ambassador_payout_setup();

-- Performance: client_orders_page.dart / client_order_page.dart previously
-- fetched every row in client_custom_requests and company_custom_requests
-- (platform-wide, unfiltered) and filtered down to "does this belong to the
-- current client" entirely in Dart. That downloads every other user's order
-- data on every load. These RPCs push a safe superset of that same
-- ownership check into Postgres so only rows that could plausibly belong to
-- the caller ever leave the database; the existing unmodified Dart-side
-- `belongs()` filter still runs afterward as the exact/final arbiter, so
-- behavior is unchanged -- this only cuts what crosses the wire.
--
-- "Superset" is deliberate: a couple of branches (id/name fallback matching)
-- are intentionally more permissive here than the original pickText-based
-- Dart logic, so this can never exclude a row the client should see. Group
-- order membership (a client invited into someone else's request via the
-- group_clients JSON array) is matched explicitly so those orders are not
-- silently dropped.

create or replace function public.matches_client_ownership(
  row_json jsonb,
  p_emails text[],
  p_uid text,
  p_name text
) returns boolean
language plpgsql
stable
as $$
declare
  summary jsonb := coalesce(row_json->'summary', '{}'::jsonb);
  details jsonb := coalesce(row_json->'details', '{}'::jsonb);
  payload jsonb := coalesce(row_json->'payload', '{}'::jsonb);
  request_details jsonb := coalesce(row_json->'request_details', '{}'::jsonb);
  details_order jsonb := coalesce(details->'order', '{}'::jsonb);
  payload_order jsonb := coalesce(payload->'order', '{}'::jsonb);
  acceptance jsonb := coalesce(summary->'acceptance', '{}'::jsonb)
    || coalesce(details->'acceptance', '{}'::jsonb)
    || coalesce(payload->'acceptance', '{}'::jsonb);
  details_group_order jsonb := coalesce(details->'groupOrder', '{}'::jsonb);
  payload_group_order jsonb := coalesce(payload->'groupOrder', '{}'::jsonb);
  request_group_order jsonb := coalesce(request_details->'groupOrder', '{}'::jsonb);
  email_candidates text[];
  id_candidates text[];
  name_candidates text[];
  group_emails text[] := '{}';
  group_entries jsonb := '[]'::jsonb;
  candidate jsonb;
  entry jsonb;
  v text;
begin
  if p_emails is null then
    p_emails := '{}';
  end if;

  email_candidates := array_remove(array[
    lower(coalesce(row_json->>'client_email','')),
    lower(coalesce(row_json->>'selected_client_email','')),
    lower(coalesce(summary->>'clientEmail','')),
    lower(coalesce(summary->>'selectedClientEmail','')),
    lower(coalesce(details->>'clientEmail','')),
    lower(coalesce(details->>'selectedClientEmail','')),
    lower(coalesce(payload->>'clientEmail','')),
    lower(coalesce(payload->>'selectedClientEmail','')),
    lower(coalesce(details_order->>'selectedClientEmail','')),
    lower(coalesce(payload_order->>'selectedClientEmail','')),
    lower(coalesce(row_json->>'accepted_by_client_email','')),
    lower(coalesce(summary->>'acceptedByClientEmail','')),
    lower(coalesce(details->>'acceptedByClientEmail','')),
    lower(coalesce(payload->>'acceptedByClientEmail','')),
    lower(coalesce(acceptance->>'acceptedByClientEmail','')),
    lower(coalesce(request_details->>'clientEmail',''))
  ], '');

  if email_candidates && p_emails then
    return true;
  end if;

  if p_uid is not null and p_uid <> '' then
    id_candidates := array_remove(array[
      coalesce(row_json->>'client_id',''),
      coalesce(row_json->>'client_uid',''),
      coalesce(summary->>'clientId',''),
      coalesce(details->>'clientId',''),
      coalesce(payload->>'clientId',''),
      coalesce(summary->>'clientUid',''),
      coalesce(details->>'clientUid',''),
      coalesce(payload->>'clientUid',''),
      coalesce(row_json->>'accepted_by_client_id',''),
      coalesce(summary->>'acceptedByClientId',''),
      coalesce(details->>'acceptedByClientId',''),
      coalesce(payload->>'acceptedByClientId',''),
      coalesce(acceptance->>'acceptedByClientId',''),
      coalesce(row_json->>'accepted_by_client_uid',''),
      coalesce(summary->>'acceptedByClientUid',''),
      coalesce(details->>'acceptedByClientUid',''),
      coalesce(payload->>'acceptedByClientUid',''),
      coalesce(acceptance->>'acceptedByClientUid','')
    ], '');
    if p_uid = any(id_candidates) then
      return true;
    end if;
  end if;

  if p_name is not null and p_name <> '' then
    name_candidates := array_remove(array[
      lower(coalesce(row_json->>'client_name','')),
      lower(coalesce(summary->>'clientName','')),
      lower(coalesce(details->>'clientName','')),
      lower(coalesce(payload->>'clientName','')),
      lower(coalesce(row_json->>'selected_client','')),
      lower(coalesce(summary->>'selectedClient','')),
      lower(coalesce(details->>'selectedClient','')),
      lower(coalesce(payload->>'selectedClient',''))
    ], '');
    if p_name = any(name_candidates) then
      return true;
    end if;
  end if;

  for candidate in
    select unnest(array[
      row_json->'selected_group_client_emails',
      row_json->'accepted_group_client_emails',
      row_json->'declined_group_client_emails',
      summary->'selectedGroupClientEmails',
      summary->'acceptedGroupClientEmails',
      details->'selectedGroupClientEmails',
      details->'acceptedGroupClientEmails',
      payload->'selectedGroupClientEmails',
      payload->'acceptedGroupClientEmails',
      details_order->'selectedGroupClientEmails',
      payload_order->'selectedGroupClientEmails'
    ])
  loop
    if candidate is not null and jsonb_typeof(candidate) = 'array' then
      for v in select jsonb_array_elements_text(candidate) loop
        group_emails := array_append(group_emails, lower(v));
      end loop;
    end if;
  end loop;

  for candidate in
    select unnest(array[
      row_json->'group_clients',
      summary->'groupClients',
      details->'groupClients',
      payload->'groupClients',
      details_group_order->'clients',
      payload_group_order->'clients',
      request_group_order->'clients'
    ])
  loop
    if candidate is not null and jsonb_typeof(candidate) = 'array' and jsonb_array_length(candidate) > 0 then
      group_entries := candidate;
      exit;
    end if;
  end loop;

  for entry in select jsonb_array_elements(group_entries) loop
    group_emails := array_append(group_emails, lower(coalesce(
      nullif(entry->>'clientEmail',''),
      nullif(entry->>'client_email',''),
      nullif(entry->>'email',''),
      ''
    )));
  end loop;

  group_emails := array_remove(group_emails, '');
  if group_emails && p_emails then
    return true;
  end if;

  return false;
end;
$$;

create or replace function public.get_client_custom_requests_for_client(
  p_emails text[],
  p_uid text,
  p_name text
) returns setof client_custom_requests
language sql
stable
as $$
  select r.* from client_custom_requests r
  where public.matches_client_ownership(to_jsonb(r), p_emails, p_uid, p_name)
  order by r.created_at desc;
$$;

create or replace function public.get_company_custom_requests_for_client(
  p_emails text[],
  p_uid text,
  p_name text
) returns setof company_custom_requests
language sql
stable
as $$
  select r.* from company_custom_requests r
  where public.matches_client_ownership(to_jsonb(r), p_emails, p_uid, p_name)
  order by r.created_at desc;
$$;

grant execute on function public.get_client_custom_requests_for_client(text[], text, text) to authenticated;
grant execute on function public.get_company_custom_requests_for_client(text[], text, text) to authenticated;
grant execute on function public.matches_client_ownership(jsonb, text[], text, text) to authenticated;

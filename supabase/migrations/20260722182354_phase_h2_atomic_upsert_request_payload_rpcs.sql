CREATE OR REPLACE FUNCTION public.upsert_client_custom_request_payload(p_id uuid, p_status text, p_details_patch jsonb, p_accepted_by_client_email text, p_declined_by_client_emails jsonb, p_open_to_client_pool boolean, p_client_response_status text, p_artist_status text, p_brand_status text, p_client_status text, p_updated_at timestamp with time zone)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  update public.client_custom_requests
  set
    status = coalesce(p_status, status),
    details = coalesce(details, '{}'::jsonb) || p_details_patch,
    accepted_by_client_email = coalesce(p_accepted_by_client_email, accepted_by_client_email),
    declined_by_client_emails = coalesce(p_declined_by_client_emails, declined_by_client_emails),
    open_to_client_pool = coalesce(p_open_to_client_pool, open_to_client_pool),
    client_response_status = coalesce(p_client_response_status, client_response_status),
    artist_status = coalesce(p_artist_status, artist_status),
    brand_status = coalesce(p_brand_status, brand_status),
    client_status = coalesce(p_client_status, client_status),
    updated_at = p_updated_at
  where id = p_id;
$function$;

GRANT EXECUTE ON FUNCTION public.upsert_client_custom_request_payload(uuid, text, jsonb, text, jsonb, boolean, text, text, text, text, timestamp with time zone) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.upsert_company_custom_request_payload(p_id uuid, p_status text, p_details_patch jsonb, p_accepted_by_client_email text, p_declined_by_client_emails jsonb, p_open_to_client_pool boolean, p_artist_status text, p_brand_status text, p_client_status text, p_updated_at timestamp with time zone)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  update public.company_custom_requests
  set
    status = coalesce(p_status, status),
    details = coalesce(details, '{}'::jsonb) || p_details_patch,
    accepted_by_client_email = coalesce(p_accepted_by_client_email, accepted_by_client_email),
    declined_by_client_emails = coalesce(p_declined_by_client_emails, declined_by_client_emails),
    open_to_client_pool = coalesce(p_open_to_client_pool, open_to_client_pool),
    artist_status = coalesce(p_artist_status, artist_status),
    brand_status = coalesce(p_brand_status, brand_status),
    client_status = coalesce(p_client_status, client_status),
    updated_at = p_updated_at
  where id = p_id;
$function$;

GRANT EXECUTE ON FUNCTION public.upsert_company_custom_request_payload(uuid, text, jsonb, text, jsonb, boolean, text, text, text, timestamp with time zone) TO anon, authenticated, service_role;

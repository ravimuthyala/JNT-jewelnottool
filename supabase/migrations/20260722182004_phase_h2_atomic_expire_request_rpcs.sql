CREATE OR REPLACE FUNCTION public.expire_client_custom_request(p_id uuid, p_details_patch jsonb, p_updated_at timestamp with time zone)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  update public.client_custom_requests
  set
    status = 'expired',
    expired_at = p_updated_at,
    expired_notified_client = true,
    details = coalesce(details, '{}'::jsonb) || p_details_patch,
    payload = coalesce(payload, '{}'::jsonb) || p_details_patch,
    updated_at = p_updated_at
  where id = p_id;
$function$;

GRANT EXECUTE ON FUNCTION public.expire_client_custom_request(uuid, jsonb, timestamp with time zone) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.expire_company_custom_request(p_id uuid, p_cancel_reason text, p_details_patch jsonb, p_updated_at timestamp with time zone, p_mark_accepted_client boolean)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  update public.company_custom_requests
  set
    status = 'cancelled',
    cancel_reason = p_cancel_reason,
    cancelled_at = p_updated_at,
    expired_notified_client = true,
    expired_notified_brand_admin = true,
    expired_notified_accepted_client = case
      when p_mark_accepted_client then true
      else expired_notified_accepted_client
    end,
    details = coalesce(details, '{}'::jsonb) || p_details_patch,
    payload = coalesce(payload, '{}'::jsonb) || p_details_patch,
    updated_at = p_updated_at
  where id = p_id;
$function$;

GRANT EXECUTE ON FUNCTION public.expire_company_custom_request(uuid, text, jsonb, timestamp with time zone, boolean) TO anon, authenticated, service_role;

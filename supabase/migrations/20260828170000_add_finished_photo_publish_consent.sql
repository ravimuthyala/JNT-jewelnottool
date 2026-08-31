-- Adds the client's consent-to-publish flag for artist-uploaded completed
-- press-on photos, captured on the designing-status "Upload Completed Set"
-- step (shared by both the artist and client-artist roles via
-- showDesigningRequestSheet). Stored as a real column, plus mirrored into
-- the existing `data`/`details`/`payload` jsonb blobs already maintained by
-- artist_mark_request_completed(), so it's queryable by admin either way.

alter table public.client_custom_requests
  add column if not exists consent_to_publish_finished_photos boolean;

drop function if exists public.artist_mark_request_completed(uuid, text, jsonb, jsonb);

create or replace function public.artist_mark_request_completed(
  p_request_id uuid,
  p_order_number text default null::text,
  p_artist_photos jsonb default '[]'::jsonb,
  p_shipping jsonb default '{}'::jsonb,
  p_consent_to_publish_finished_photos boolean default false
)
returns jsonb
language plpgsql
security definer
as $function$
declare
  v_now timestamptz := now();
begin
  update public.client_custom_requests
  set
    status = 'completed',
    client_status = 'completed',
    artist_status = 'completed',
    artist_completed_photos = p_artist_photos,
    completed_at = v_now,
    shipping_status = 'label_ready',
    consent_to_publish_finished_photos = p_consent_to_publish_finished_photos,
    updated_at = v_now,
    data = coalesce(data, '{}'::jsonb) || jsonb_build_object(
      'status', 'completed',
      'clientStatus', 'completed',
      'artistStatus', 'completed',
      'artistCompletedPhotos', p_artist_photos,
      'completedAt', v_now,
      'completionReviewStatus', 'pending_client',
      'shipping', p_shipping,
      'shippingStatus', 'label_ready',
      'consentToPublishFinishedPhotos', p_consent_to_publish_finished_photos
    )
  where id = p_request_id
     or order_number = p_order_number
     or request_number = p_order_number;

  update public.client_custom_requests_details
  set
    data = coalesce(data, '{}'::jsonb) || jsonb_build_object(
      'status', 'completed',
      'clientStatus', 'completed',
      'artistStatus', 'completed',
      'artistCompletedPhotos', p_artist_photos,
      'completedAt', v_now,
      'completionReviewStatus', 'pending_client',
      'shipping', p_shipping,
      'shippingStatus', 'label_ready',
      'consentToPublishFinishedPhotos', p_consent_to_publish_finished_photos
    ),
    updated_at = v_now
  where request_id = p_request_id;

  update public.company_custom_requests
  set
    status = 'completed',
    brand_status = 'completed',
    client_status = 'completed',
    artist_status = 'completed',
    updated_at = v_now,
    payload = coalesce(payload, '{}'::jsonb) || jsonb_build_object(
      'status', 'completed',
      'brandStatus', 'completed',
      'clientStatus', 'completed',
      'artistStatus', 'completed',
      'artistCompletedPhotos', p_artist_photos,
      'completedAt', v_now,
      'shipping', p_shipping,
      'consentToPublishFinishedPhotos', p_consent_to_publish_finished_photos
    ),
    details = coalesce(details, '{}'::jsonb) || jsonb_build_object(
      'status', 'completed',
      'brandStatus', 'completed',
      'clientStatus', 'completed',
      'artistStatus', 'completed',
      'artistCompletedPhotos', p_artist_photos,
      'completedAt', v_now,
      'shipping', p_shipping,
      'consentToPublishFinishedPhotos', p_consent_to_publish_finished_photos
    )
  where id = p_request_id
     or order_number = p_order_number
     or request_number = p_order_number;

  return jsonb_build_object('success', true);
end;
$function$;

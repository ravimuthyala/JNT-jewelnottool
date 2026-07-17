


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."admin_create_shipping_qr"("p_request_id" "uuid", "p_order_number" "text" DEFAULT NULL::"text", "p_carrier" "text" DEFAULT 'USPS'::"text", "p_tracking_number" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_qr text;
  v_now timestamptz := now();
begin
  v_qr :=
    'JNT_SHIP|collection=Client_Custom_Requests'
    || '|orderDocId=' || p_request_id::text
    || '|orderNumber=' || coalesce(p_order_number, '')
    || '|action=confirm_shipment';

  update public.client_custom_requests
  set
    shipping_label_ready = true,
    shipping_status = 'label_ready',
    shipping_label_qr_data = v_qr,
    shipping_qr_code = v_qr,
    shipping_label_carrier = p_carrier,
    shipping_label_tracking_number = p_tracking_number,
    shipping_label_created_at = v_now,
    updated_at = v_now,
    data = coalesce(data, '{}'::jsonb) || jsonb_build_object(
      'shippingLabelReady', true,
      'shippingStatus', 'label_ready',
      'shippingLabelQrData', v_qr,
      'shippingQrCode', v_qr,
      'shippingLabelCarrier', p_carrier,
      'shippingLabelTrackingNumber', p_tracking_number,
      'shippingLabelCreatedAt', v_now
    )
  where id = p_request_id
     or order_number = p_order_number
     or request_number = p_order_number;

  return jsonb_build_object(
    'success', true,
    'qr', v_qr
  );
end;
$$;


ALTER FUNCTION "public"."admin_create_shipping_qr"("p_request_id" "uuid", "p_order_number" "text", "p_carrier" "text", "p_tracking_number" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."artist_accept_request"("p_request_id" "uuid", "p_artist_amount" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_artist_email text := lower(auth.jwt() ->> 'email');
begin
  update public.company_custom_requests
  set
    status = 'designing',
    artist_status = 'designing',
    accepted_by_artist_email = v_artist_email,
    artist_final_amount = coalesce(p_artist_amount, artist_final_amount),
    updated_at = now()
  where id = p_request_id;

  update public.client_custom_requests
  set
    status = 'designing',
    artist_status = 'designing',
    accepted_by_artist_email = v_artist_email,
    artist_final_amount = coalesce(p_artist_amount, artist_final_amount),
    updated_at = now()
  where id = p_request_id;

  return jsonb_build_object('success', true);
end;
$$;


ALTER FUNCTION "public"."artist_accept_request"("p_request_id" "uuid", "p_artist_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."artist_accept_request"("p_request_id" "uuid", "p_order_number" "text" DEFAULT NULL::"text", "p_artist_amount" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_artist_email text := lower(auth.jwt() ->> 'email');
  v_now timestamptz := now();
begin
  update public.company_custom_requests
  set
    status = 'designing',
    brand_status = 'in_progress',
    client_status = 'in_progress',
    artist_status = 'designing',
    accepted_by_artist_email = v_artist_email,
    artist_final_amount = coalesce(p_artist_amount, artist_final_amount),
    payment_status = 'pending',
    updated_at = v_now,
    payload = coalesce(payload, '{}'::jsonb) || jsonb_build_object(
      'status', 'designing',
      'brandStatus', 'in_progress',
      'clientStatus', 'in_progress',
      'artistStatus', 'designing',
      'directArtistStatus', 'designing',
      'artistPoolStatus', 'designing',
      'acceptedByArtistEmail', v_artist_email,
      'acceptedByArtistAt', v_now,
      'artistFinalAmount', p_artist_amount,
      'paymentStatus', 'pending'
    ),
    details = coalesce(details, '{}'::jsonb) || jsonb_build_object(
      'status', 'designing',
      'brandStatus', 'in_progress',
      'clientStatus', 'in_progress',
      'artistStatus', 'designing',
      'directArtistStatus', 'designing',
      'artistPoolStatus', 'designing',
      'acceptedByArtistEmail', v_artist_email,
      'acceptedByArtistAt', v_now,
      'artistFinalAmount', p_artist_amount,
      'paymentStatus', 'pending'
    )
  where id = p_request_id
     or order_number = p_order_number
     or request_number = p_order_number;

  update public.client_custom_requests
  set
    status = 'designing',
    client_status = 'in_progress',
    artist_status = 'designing',
    accepted_by_artist_email = v_artist_email,
    artist_final_amount = coalesce(p_artist_amount, artist_final_amount),
    final_amount_by_artist = coalesce(p_artist_amount, final_amount_by_artist),
    payment_status = 'pending',
    updated_at = v_now,
    data = coalesce(data, '{}'::jsonb) || jsonb_build_object(
      'status', 'designing',
      'clientStatus', 'in_progress',
      'artistStatus', 'designing',
      'acceptedByArtistEmail', v_artist_email,
      'acceptedByArtistAt', v_now,
      'artistFinalAmount', p_artist_amount,
      'paymentStatus', 'pending'
    )
  where id = p_request_id
     or order_number = p_order_number
     or request_number = p_order_number;

  update public.company_custom_requests_details
  set
    data = coalesce(data, '{}'::jsonb) || jsonb_build_object(
      'status', 'designing',
      'brandStatus', 'in_progress',
      'clientStatus', 'in_progress',
      'artistStatus', 'designing',
      'acceptedByArtistEmail', v_artist_email,
      'artistFinalAmount', p_artist_amount,
      'paymentStatus', 'pending'
    ),
    updated_at = v_now
  where request_id = p_request_id;

  update public.client_custom_requests_details
  set
    data = coalesce(data, '{}'::jsonb) || jsonb_build_object(
      'status', 'designing',
      'clientStatus', 'in_progress',
      'artistStatus', 'designing',
      'acceptedByArtistEmail', v_artist_email,
      'artistFinalAmount', p_artist_amount,
      'paymentStatus', 'pending'
    ),
    updated_at = v_now
  where request_id = p_request_id;

  return jsonb_build_object('success', true);
end;
$$;


ALTER FUNCTION "public"."artist_accept_request"("p_request_id" "uuid", "p_order_number" "text", "p_artist_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."artist_decline_request"("p_request_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  update public.client_custom_requests
  set
    status = 'declined',
    artist_status = 'declined',
    accepted_by_artist_email = null,
    updated_at = now(),
    data = coalesce(data, '{}'::jsonb) || jsonb_build_object(
      'artistStatus', 'declined',
      'declinedByArtistEmail', lower(auth.jwt() ->> 'email'),
      'artistDeclinedAt', now()
    )
  where id = p_request_id;

  update public.company_custom_requests
  set
    artist_status = 'declined',
    direct_artist_status = 'declined',
    updated_at = now(),
    data = coalesce(data, '{}'::jsonb) || jsonb_build_object(
      'artistStatus', 'declined',
      'directArtistStatus', 'declined',
      'declinedByArtistEmail', lower(auth.jwt() ->> 'email'),
      'artistDeclinedAt', now()
    )
  where id = p_request_id;
end;
$$;


ALTER FUNCTION "public"."artist_decline_request"("p_request_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."artist_mark_request_completed"("p_request_id" "uuid", "p_order_number" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_photos jsonb := '[]'::jsonb;
begin
  select coalesce(artist_completion_draft_photos, '[]'::jsonb)
  into v_photos
  from public.client_custom_requests
  where id = p_request_id
     or order_number = p_order_number
     or request_number = p_order_number
  limit 1;

  update public.client_custom_requests
  set
    status = 'completed',
    client_status = 'completed',
    artist_status = 'completed',
    artist_completed_photos = v_photos,
    completed_at = now(),
    updated_at = now()
  where id = p_request_id
     or order_number = p_order_number
     or request_number = p_order_number;

  return jsonb_build_object('success', true, 'photos', v_photos);
end;
$$;


ALTER FUNCTION "public"."artist_mark_request_completed"("p_request_id" "uuid", "p_order_number" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."artist_mark_request_completed"("p_request_id" "uuid", "p_order_number" "text" DEFAULT NULL::"text", "p_artist_photos" "jsonb" DEFAULT '[]'::"jsonb", "p_shipping" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
    updated_at = v_now,
    data = coalesce(data, '{}'::jsonb) || jsonb_build_object(
      'status', 'completed',
      'clientStatus', 'completed',
      'artistStatus', 'completed',
      'artistCompletedPhotos', p_artist_photos,
      'completedAt', v_now,
      'completionReviewStatus', 'pending_client',
      'shipping', p_shipping,
      'shippingStatus', 'label_ready'
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
      'shippingStatus', 'label_ready'
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
      'shipping', p_shipping
    ),
    details = coalesce(details, '{}'::jsonb) || jsonb_build_object(
      'status', 'completed',
      'brandStatus', 'completed',
      'clientStatus', 'completed',
      'artistStatus', 'completed',
      'artistCompletedPhotos', p_artist_photos,
      'completedAt', v_now,
      'shipping', p_shipping
    )
  where id = p_request_id
     or order_number = p_order_number
     or request_number = p_order_number;

  return jsonb_build_object('success', true);
end;
$$;


ALTER FUNCTION "public"."artist_mark_request_completed"("p_request_id" "uuid", "p_order_number" "text", "p_artist_photos" "jsonb", "p_shipping" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."client_request_before_save_defaults"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.client_uid is null then
    new.client_uid := new.client_id;
  end if;

  if new.order_number is null or btrim(new.order_number) = '' then
    new.order_number := 'CR-' || lpad((floor(random() * 90000 + 10000))::text, 5, '0');
  end if;

  if new.request_number is null or btrim(new.request_number) = '' then
    new.request_number := new.order_number;
  end if;

  if new.client_request_number is null or btrim(new.client_request_number) = '' then
    new.client_request_number := new.order_number;
  end if;

  if new.status is null then new.status := 'pending'; end if;
  if new.client_status is null then new.client_status := 'pending'; end if;
  if new.artist_status is null then new.artist_status := 'in_review'; end if;

  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION "public"."client_request_before_save_defaults"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."client_request_mirror_legacy_json"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  legacy jsonb;
begin
  legacy := jsonb_strip_nulls(jsonb_build_object(
    'id', new.id,
    'sourceCollection', 'Client_Custom_Requests',
    'orderNumber', new.order_number,
    'requestNumber', new.request_number,
    'clientRequestNumber', new.client_request_number,
    'requestType', new.request_type,
    'orderType', new.order_type,
    'status', new.status,
    'clientStatus', new.client_status,
    'artistStatus', new.artist_status,
    'clientId', new.client_id,
    'clientUid', coalesce(new.client_uid, new.client_id),
    'clientEmail', new.client_email,
    'clientName', new.client_name,
    'artistEmail', new.artist_email,
    'artistName', new.artist_name,
    'selectedArtist', new.selected_artist,
    'selectedArtistEmail', new.selected_artist_email,
    'acceptedByArtistEmail', new.accepted_by_artist_email,
    'acceptedByArtistName', new.accepted_by_artist_name,
    'needBy', new.need_by,
    'needByDisplay', new.need_by_display,
    'description', new.description,
    'descriptionPreview', new.description_preview,
    'budgetMin', new.budget_min,
    'budgetMax', new.budget_max,
    'nailShape', new.nail_shape,
    'nailLength', new.nail_length,
    'nailPreferences', new.nail_preferences,
    'shipping', new.shipping,
    'isDirectRequest', new.is_direct_request,
    'fallbackToPool', new.fallback_to_pool,
    'allowNonLicensed', new.allow_non_licensed,
    'isGroupOrder', new.is_group_order,
    'groupClients', new.group_clients,
    'groupClientCount', new.group_client_count,
    'nfcEligible', new.nfc_eligible,
    'eligibleForNfc', new.eligible_for_nfc,
    'nfcRequested', new.nfc_requested,
    'nfcSelected', new.nfc_selected,
    'nfcCount', new.nfc_count,
    'inspirationPhotos', new.inspiration_photos,
    'photoCount', new.photo_count,
    'hasInspirationPhotos', new.has_inspiration_photos,
    'paymentStatus', new.payment_status,
    'paidAt', new.paid_at,
    'shippingStatus', new.shipping_status,
    'trackingNumber', new.tracking_number,
    'shippedByCourier', new.shipped_by_courier,
    'shippedAt', new.shipped_at,
    'deliveredAt', new.delivered_at,
    'createdAt', new.created_at,
    'updatedAt', new.updated_at
  ));

  new.summary := coalesce(new.summary, '{}'::jsonb) || legacy;
  new.details := coalesce(new.details, '{}'::jsonb) || legacy;
  new.payload := coalesce(new.payload, '{}'::jsonb) || legacy;
  new.data := coalesce(new.data, '{}'::jsonb) || legacy;
  return new;
end;
$$;


ALTER FUNCTION "public"."client_request_mirror_legacy_json"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."company_custom_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "company_uid" "uuid",
    "requester_uid" "uuid",
    "created_by_uid" "uuid",
    "uid" "uuid",
    "company_email" "text",
    "client_email" "text",
    "requester_email" "text",
    "email" "text",
    "company_name" "text",
    "brand_name" "text",
    "client_name" "text",
    "requester_name" "text",
    "campaign_name" "text",
    "title" "text",
    "request_title" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "request_type" "text",
    "payload" "jsonb" DEFAULT '{}'::"jsonb",
    "details" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "selected_client_email" "text",
    "selected_artist_email" "text",
    "selected_group_client_emails" "jsonb" DEFAULT '[]'::"jsonb",
    "order_number" "text",
    "request_type_label" "text",
    "request_type_display" "text",
    "brand_status" "text" DEFAULT 'pending'::"text",
    "client_status" "text" DEFAULT 'pending'::"text",
    "artist_status" "text" DEFAULT 'pending'::"text",
    "description_preview" "text",
    "need_by" timestamp with time zone,
    "request_accept_by" timestamp with time zone,
    "request_accept_by_display" "text",
    "jnt_reveal_date" timestamp with time zone,
    "jnt_reveal_date_display" "text",
    "budget_min" integer,
    "budget_max" integer,
    "client_budget_min" integer,
    "client_budget_max" integer,
    "artist_budget_min" integer,
    "artist_budget_max" integer,
    "is_direct_request" boolean DEFAULT false,
    "fallback_to_pool" boolean DEFAULT true,
    "open_to_client_pool" boolean DEFAULT true,
    "open_to_artist_pool" boolean DEFAULT true,
    "nfc_requested" boolean DEFAULT false,
    "requires_nfc_eligible_client" boolean DEFAULT false,
    "eligible_nfc_client_emails" "jsonb" DEFAULT '[]'::"jsonb",
    "selected_artist" "text",
    "selected_client" "text",
    "order_type" "text" DEFAULT 'single'::"text",
    "order_type_label" "text",
    "who_receives_order" "text",
    "who_creates_design" "text",
    "quantity" integer DEFAULT 1,
    "number_of_sets" integer DEFAULT 1,
    "has_inspiration_photos" boolean DEFAULT false,
    "photo_count" integer DEFAULT 0,
    "photo_upload_status" "text" DEFAULT 'none'::"text",
    "photo_upload_error" "text",
    "photo_upload_completed_at" timestamp with time zone,
    "photo_upload_failed_at" timestamp with time zone,
    "brand_has_inspiration_photos" boolean DEFAULT false,
    "brand_photo_count" integer DEFAULT 0,
    "brand_inspiration_photos" "jsonb" DEFAULT '[]'::"jsonb",
    "inspiration_photos" "jsonb" DEFAULT '[]'::"jsonb",
    "preview_image" "text",
    "preview_image_asset" "text",
    "client_location" "text",
    "bio" "text",
    "company_bio" "text",
    "panel_company_bio" "text",
    "nail_shape" "text",
    "nail_length" "text",
    "nail_preferences" "jsonb" DEFAULT '{}'::"jsonb",
    "client_profile_image" "text",
    "shipping_address_different_from_profile" boolean DEFAULT false,
    "shipping_street" "text",
    "shipping_city" "text",
    "shipping_state" "text",
    "shipping_zip" "text",
    "shipping_country" "text",
    "shipping" "jsonb" DEFAULT '{}'::"jsonb",
    "admin" "jsonb" DEFAULT '{}'::"jsonb",
    "source_collection" "text" DEFAULT 'Company_Custom_Requests'::"text",
    "accepted_by_artist_email" "text",
    "accepted_by_artist_name" "text",
    "accepted_by_client_email" "text",
    "artist_final_amount" numeric,
    "payment_status" "text",
    "payment_link" "text",
    "paid_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    "cancel_reason" "text",
    "expired_at" timestamp with time zone,
    "expired_notified_client" boolean DEFAULT false,
    "expired_notified_brand_admin" boolean DEFAULT false,
    "expired_notified_accepted_client" boolean DEFAULT false,
    "group_clients" "jsonb" DEFAULT '[]'::"jsonb",
    "left_hand_dimensions" "jsonb" DEFAULT '{}'::"jsonb",
    "right_hand_dimensions" "jsonb" DEFAULT '{}'::"jsonb",
    "artist_profile_image" "text",
    "artist_completed_photos" "jsonb" DEFAULT '[]'::"jsonb",
    "completion_review_status" "text",
    "completion_decline_reason" "text",
    "completion_decline_description" "text",
    "completion_declined_at" timestamp with time zone,
    "design_approval_status" "text",
    "design_approved_at" timestamp with time zone,
    "design_submitted_at" timestamp with time zone,
    "design_approval_due_at" timestamp with time zone,
    "design_reminder_sent_at" timestamp with time zone,
    "design_preview_photos" "jsonb" DEFAULT '[]'::"jsonb",
    "direct_client_status" "text",
    "direct_artist_status" "text",
    "rating" numeric,
    "review_text" "text",
    "review_submitted_at" timestamp with time zone,
    "shipped_by_courier" "text",
    "tracking_number" "text",
    "shipped_at" timestamp with time zone,
    "delivered_at" timestamp with time zone,
    "payment" "jsonb" DEFAULT '{}'::"jsonb",
    "payment_notified_artist" boolean DEFAULT false,
    "payment_notified_artist_at" timestamp with time zone,
    "client_budget" "jsonb" DEFAULT '{}'::"jsonb",
    "artist_budget" "jsonb" DEFAULT '{}'::"jsonb",
    "client_review" "jsonb" DEFAULT '{}'::"jsonb",
    "client_rating" numeric,
    "client_review_text" "text",
    "client_review_submitted_at" timestamp with time zone,
    "client_review_prompt_sent_at" timestamp with time zone,
    "client_review_prompt_channel" "text",
    "tip_amount" numeric DEFAULT 0,
    "tip_percent" integer,
    "custom_tip_amount" numeric DEFAULT 0,
    "tipped_at" timestamp with time zone,
    "cancelled_by" "text",
    "cancelled_by_email" "text",
    "cancellation_reason" "text",
    "cancellation_notified_at" timestamp with time zone,
    "accepted_group_client_emails" "jsonb" DEFAULT '[]'::"jsonb",
    "declined_group_client_emails" "jsonb" DEFAULT '[]'::"jsonb",
    "declined_by_client_emails" "jsonb" DEFAULT '[]'::"jsonb",
    "declined_by_artist_emails" "jsonb" DEFAULT '[]'::"jsonb",
    "review_prompt" "jsonb" DEFAULT '{}'::"jsonb",
    "delivery_prompt" "jsonb" DEFAULT '{}'::"jsonb",
    "admin_notes" "jsonb" DEFAULT '[]'::"jsonb",
    "admin_note_count" integer DEFAULT 0,
    "latest_admin_note" "text",
    "latest_admin_note_at" timestamp with time zone,
    "accepted_client_name" "text",
    "accepted_by_client_name" "text",
    "artist_name" "text",
    "artist_email" "text",
    "request_number" "text",
    "brand_request_number" "text",
    "description" "text",
    "request_details" "jsonb" DEFAULT '{}'::"jsonb",
    "summary" "jsonb" DEFAULT '{}'::"jsonb",
    "order_data" "jsonb" DEFAULT '{}'::"jsonb",
    "completed_at" timestamp with time zone,
    "artist_completed_at" timestamp with time zone,
    "artist_shipped_at" timestamp with time zone,
    "delivery_date" timestamp with time zone,
    "payments" "jsonb" DEFAULT '{}'::"jsonb",
    "checkout" "jsonb" DEFAULT '{}'::"jsonb",
    "invoice" "jsonb" DEFAULT '{}'::"jsonb",
    "payment_method" "text",
    "payment_amount" numeric,
    "paid_amount" numeric,
    "amount" numeric,
    "total_amount" numeric,
    "final_amount_by_artist" numeric,
    "currency" "text" DEFAULT 'USD'::"text",
    "card_last4" "text",
    "transaction_id" "text",
    "invoice_number" "text",
    "payment_received_at" timestamp with time zone,
    "shipping_status" "text",
    "order_shipped_at" timestamp with time zone,
    "order_delivered_at" timestamp with time zone,
    "review" "jsonb" DEFAULT '{}'::"jsonb",
    "brand_review" "jsonb" DEFAULT '{}'::"jsonb",
    "review_comment" "text",
    "client_review_comment" "text",
    "brand_review_comment" "text",
    "review_stars" integer,
    "client_review_stars" integer,
    "brand_review_stars" integer,
    "reviewed_at" timestamp with time zone,
    "tips_amount" numeric DEFAULT 0,
    "estimated_delivery_at" timestamp with time zone,
    "tracking" "jsonb" DEFAULT '{}'::"jsonb",
    "artist_quote" "jsonb" DEFAULT '{}'::"jsonb",
    "artist_pool_status" "text",
    "direct_request_released_to_pool_at" timestamp with time zone,
    "direct_request_released_by_artist_email" "text",
    "client_tip_amount" numeric,
    "client_tip_percent" numeric,
    "client_tip_custom_amount" numeric,
    "client_tip_submitted_at" timestamp with time zone,
    "shipping_label_qr_data" "text",
    "shipping_label_ready" boolean DEFAULT false NOT NULL,
    "shipping_label_pdf_url" "text",
    "shipping_label_carrier" "text",
    "shipping_label_tracking_number" "text",
    "shipping_label_created_at" timestamp with time zone,
    "artist_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "artist_uploaded_photos" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "completed_art" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "completed_photos" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "accepted_by_client_at" timestamp with time zone,
    "client_avatar_url" "text",
    "selected_client_avatar_url" "text",
    "client_tip" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "tip" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "nail_size" "text",
    "artist_completion_draft_photos" "jsonb" DEFAULT '[]'::"jsonb"
);


ALTER TABLE "public"."company_custom_requests" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_brand_requests_for_company_app"() RETURNS SETOF "public"."company_custom_requests"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  select *
  from public.company_custom_requests
  where
    company_uid = auth.uid()
    or requester_uid = auth.uid()
    or created_by_uid = auth.uid()
    or uid = auth.uid()
    or lower(company_email) = lower(auth.jwt() ->> 'email')
    or lower(client_email) = lower(auth.jwt() ->> 'email')
  order by created_at desc;
$$;


ALTER FUNCTION "public"."get_brand_requests_for_company_app"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_custom_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "uuid",
    "client_email" "text",
    "client_name" "text",
    "selected_artist" "text",
    "selected_artist_email" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "summary" "jsonb" DEFAULT '{}'::"jsonb",
    "details" "jsonb" DEFAULT '{}'::"jsonb",
    "inspiration_photos" "jsonb" DEFAULT '[]'::"jsonb",
    "photo_count" integer DEFAULT 0,
    "has_inspiration_photos" boolean DEFAULT false,
    "photo_upload_status" "text",
    "photo_upload_error" "text",
    "photo_upload_attempt" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "photo_upload_updated_at" timestamp with time zone,
    "client_status" "text",
    "artist_status" "text",
    "order_number" "text",
    "cancel_reason" "text",
    "cancelled_at" timestamp with time zone,
    "accepted_by_artist_email" "text",
    "accepted_by_artist_name" "text",
    "artist_profile_image" "text",
    "artist_final_amount" numeric,
    "payment_status" "text",
    "payment_link" "text",
    "paid_at" timestamp with time zone,
    "design_approval_status" "text",
    "design_approved_at" timestamp with time zone,
    "design_submitted_at" timestamp with time zone,
    "design_approval_due_at" timestamp with time zone,
    "design_reminder_sent_at" timestamp with time zone,
    "design_preview_photos" "jsonb" DEFAULT '[]'::"jsonb",
    "artist_completed_photos" "jsonb" DEFAULT '[]'::"jsonb",
    "shipped_by_courier" "text",
    "tracking_number" "text",
    "shipped_at" timestamp with time zone,
    "delivered_at" timestamp with time zone,
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "source_collection" "text" DEFAULT 'Client_Custom_Requests'::"text",
    "request_number" "text",
    "client_request_number" "text",
    "title" "text",
    "request_type" "text",
    "order_type" "text",
    "client_uid" "uuid",
    "artist_email" "text",
    "artist_name" "text",
    "description" "text",
    "description_preview" "text",
    "need_by" timestamp with time zone,
    "budget_min" integer,
    "budget_max" integer,
    "nail_shape" "text",
    "nail_length" "text",
    "nail_preferences" "jsonb" DEFAULT '{}'::"jsonb",
    "left_hand_dimensions" "jsonb" DEFAULT '{}'::"jsonb",
    "right_hand_dimensions" "jsonb" DEFAULT '{}'::"jsonb",
    "preview_image" "text",
    "preview_image_asset" "text",
    "completed_at" timestamp with time zone,
    "admin_notes" "jsonb" DEFAULT '[]'::"jsonb",
    "admin_note_count" integer DEFAULT 0,
    "latest_admin_note" "text",
    "latest_admin_note_at" timestamp with time zone,
    "payload" "jsonb" DEFAULT '{}'::"jsonb",
    "request_details" "jsonb" DEFAULT '{}'::"jsonb",
    "order_data" "jsonb" DEFAULT '{}'::"jsonb",
    "payment" "jsonb" DEFAULT '{}'::"jsonb",
    "payments" "jsonb" DEFAULT '{}'::"jsonb",
    "checkout" "jsonb" DEFAULT '{}'::"jsonb",
    "invoice" "jsonb" DEFAULT '{}'::"jsonb",
    "payment_method" "text",
    "payment_amount" numeric,
    "paid_amount" numeric,
    "amount" numeric,
    "total_amount" numeric,
    "final_amount_by_artist" numeric,
    "currency" "text" DEFAULT 'USD'::"text",
    "card_last4" "text",
    "transaction_id" "text",
    "invoice_number" "text",
    "payment_received_at" timestamp with time zone,
    "shipping_status" "text",
    "artist_shipped_at" timestamp with time zone,
    "order_shipped_at" timestamp with time zone,
    "order_delivered_at" timestamp with time zone,
    "review" "jsonb" DEFAULT '{}'::"jsonb",
    "client_review" "jsonb" DEFAULT '{}'::"jsonb",
    "brand_review" "jsonb" DEFAULT '{}'::"jsonb",
    "review_comment" "text",
    "client_review_comment" "text",
    "brand_review_comment" "text",
    "review_stars" integer,
    "client_review_stars" integer,
    "brand_review_stars" integer,
    "reviewed_at" timestamp with time zone,
    "review_submitted_at" timestamp with time zone,
    "tip_amount" numeric DEFAULT 0,
    "tips_amount" numeric DEFAULT 0,
    "estimated_delivery_at" timestamp with time zone,
    "shipping" "jsonb" DEFAULT '{}'::"jsonb",
    "tracking" "jsonb" DEFAULT '{}'::"jsonb",
    "need_by_display" "text",
    "is_direct_request" boolean DEFAULT false,
    "fallback_to_pool" boolean DEFAULT true,
    "allow_non_licensed" boolean DEFAULT true,
    "is_group_order" boolean DEFAULT false,
    "group_clients" "jsonb" DEFAULT '[]'::"jsonb",
    "group_client_count" integer DEFAULT 0,
    "nfc_eligible" boolean DEFAULT false,
    "eligible_for_nfc" boolean DEFAULT false,
    "nfc_requested" boolean DEFAULT false,
    "nfc_selected" boolean DEFAULT false,
    "nfc_count" integer DEFAULT 0,
    "photo_upload_completed_at" timestamp with time zone,
    "photo_upload_failed_at" timestamp with time zone,
    "payment_notified_artist" boolean DEFAULT false,
    "payment_notified_artist_at" timestamp with time zone,
    "expired_at" timestamp with time zone,
    "expired_notified_client" boolean DEFAULT false,
    "brand_status" "text",
    "artist_quote" "jsonb" DEFAULT '{}'::"jsonb",
    "artist_completed_at" timestamp with time zone,
    "declined_by_artist_emails" "jsonb" DEFAULT '[]'::"jsonb",
    "open_to_artist_pool" boolean DEFAULT true,
    "direct_artist_status" "text",
    "artist_pool_status" "text",
    "direct_request_released_to_pool_at" timestamp with time zone,
    "direct_request_released_by_artist_email" "text",
    "client_budget_min" integer,
    "client_budget_max" integer,
    "open_to_client_pool" boolean DEFAULT true,
    "declined_by_client_emails" "jsonb" DEFAULT '[]'::"jsonb",
    "accepted_by_client_email" "text",
    "client_review_prompt_sent_at" timestamp with time zone,
    "client_rating" numeric,
    "client_review_text" "text",
    "client_review_submitted_at" timestamp with time zone,
    "client_tip_amount" numeric,
    "client_tip_percent" numeric,
    "client_tip_custom_amount" numeric,
    "client_tip_submitted_at" timestamp with time zone,
    "client_response_status" "text",
    "direct_client_status" "text",
    "campaign_name" "text",
    "contact_name" "text",
    "request_accept_by" timestamp with time zone,
    "request_accept_by_display" "text",
    "completion_review_status" "text",
    "completion_decline_reason" "text",
    "completion_decline_description" "text",
    "completion_declined_at" timestamp with time zone,
    "shipping_label_qr_data" "text",
    "shipping_label_ready" boolean DEFAULT false NOT NULL,
    "shipping_label_pdf_url" "text",
    "shipping_label_carrier" "text",
    "shipping_label_tracking_number" "text",
    "shipping_label_created_at" timestamp with time zone,
    "artist_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "artist_uploaded_photos" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "completed_art" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "completed_photos" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "selected_client" "text",
    "selected_client_email" "text",
    "accepted_by_client_name" "text",
    "accepted_by_client_at" timestamp with time zone,
    "artist_accepted_at" timestamp with time zone,
    "accepted_at" timestamp with time zone,
    "cancelled_by" "text",
    "last_client_declined_at" timestamp with time zone,
    "released_to_artist_pool_at" timestamp with time zone,
    "released_to_client_pool_at" timestamp with time zone,
    "accepted_client_name" "text",
    "client_avatar_url" "text",
    "selected_client_avatar_url" "text",
    "client_tip" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "tip" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "nail_size" "text",
    "artist_completion_draft_photos" "jsonb" DEFAULT '[]'::"jsonb",
    "shipping_qr_code" "text",
    "declined_artist_name" "text",
    "declined_artist_email" "text"
);

ALTER TABLE ONLY "public"."client_custom_requests" REPLICA IDENTITY FULL;


ALTER TABLE "public"."client_custom_requests" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_client_requests_for_app"() RETURNS SETOF "public"."client_custom_requests"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  select *
  from public.client_custom_requests
  where lower(client_email) = lower(auth.jwt() ->> 'email')
  order by created_at desc;
$$;


ALTER FUNCTION "public"."get_client_requests_for_app"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_admin_client_registered"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  client_display_name text;
  client_display_email text;
begin
  client_display_name := coalesce(
    new.panel_display_name,
    new.panel_name,
    new.profile->>'displayName',
    new.profile->>'name',
    new.basic->>'name',
    new.email,
    'New Client'
  );

  client_display_email := coalesce(
    new.panel_email,
    new.email,
    new.profile->>'email',
    new.basic->>'email'
  );

  insert into public.admin_notifications (
    id,
    type,
    source,
    request_id,
    title,
    message,
    client_name,
    registered_name,
    date_label,
    event_at,
    expires_at,
    created_at,
    updated_at,
    payload
  )
  values (
    'client_registered_' || new.id::text,
    'newUserRegistered',
    tg_table_name,
    new.id::text,
    'New Client Registration',
    'New client registration: ' || client_display_name,
    client_display_name,
    client_display_name,
    to_char(now(), 'MM/DD/YYYY HH12:MI AM'),
    now(),
    now() + interval '15 days',
    now(),
    now(),
    jsonb_build_object(
      'type', 'newUserRegistered',
      'source', tg_table_name,
      'clientId', new.id,
      'clientName', client_display_name,
      'clientEmail', client_display_email,
      'registeredName', client_display_name,
      'eventAt', now()
    )
  )
  on conflict (id) do update set
    message = excluded.message,
    client_name = excluded.client_name,
    registered_name = excluded.registered_name,
    event_at = excluded.event_at,
    expires_at = excluded.expires_at,
    updated_at = now(),
    payload = excluded.payload;

  return new;
end;
$$;


ALTER FUNCTION "public"."notify_admin_client_registered"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_admin_client_request_created"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  request_label text;
  client_display_name text;
  artist_display_name text;
begin
  request_label := coalesce(
    new.order_number,
    new.request_number,
    new.client_request_number,
    new.id::text
  );

  client_display_name := coalesce(
    new.client_name,
    new.summary->>'clientName',
    new.payload->>'clientName',
    new.details->>'clientName',
    new.client_email,
    'Client'
  );

  artist_display_name := coalesce(
    new.accepted_by_artist_name,
    new.selected_artist,
    new.artist_name,
    new.summary->>'selectedArtist',
    new.payload->>'selectedArtist',
    ''
  );

  insert into public.admin_notifications (
    id,
    type,
    source,
    request_id,
    title,
    message,
    client_name,
    artist_name,
    date_label,
    event_at,
    expires_at,
    created_at,
    updated_at,
    payload
  )
  values (
    'client_request_created_' || new.id::text,
    'newClientRequest',
    'Client_Custom_Requests',
    new.id::text,
    'New Client Request',
    'New client request ' || request_label || ' submitted by ' || client_display_name,
    client_display_name,
    artist_display_name,
    to_char(now(), 'MM/DD/YYYY HH12:MI AM'),
    now(),
    now() + interval '15 days',
    now(),
    now(),
    jsonb_build_object(
      'type', 'newClientRequest',
      'source', 'Client_Custom_Requests',
      'requestId', new.id,
      'requestNumber', request_label,
      'clientName', client_display_name,
      'clientEmail', new.client_email,
      'artistName', artist_display_name,
      'artistEmail', coalesce(new.selected_artist_email, new.artist_email),
      'eventAt', now()
    )
  )
  on conflict (id) do update set
    message = excluded.message,
    client_name = excluded.client_name,
    artist_name = excluded.artist_name,
    event_at = excluded.event_at,
    expires_at = excluded.expires_at,
    updated_at = now(),
    payload = excluded.payload;

  return new;
end;
$$;


ALTER FUNCTION "public"."notify_admin_client_request_created"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_artist_completion_photos"("p_request_id" "uuid", "p_order_number" "text" DEFAULT NULL::"text", "p_photos" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  update public.client_custom_requests
  set
    artist_completion_draft_photos = p_photos,
    updated_at = now()
  where id = p_request_id
     or order_number = p_order_number
     or request_number = p_order_number;

  update public.company_custom_requests
  set
    artist_completion_draft_photos = p_photos,
    updated_at = now()
  where id = p_request_id
     or order_number = p_order_number;

  return jsonb_build_object('success', true);
end;
$$;


ALTER FUNCTION "public"."save_artist_completion_photos"("p_request_id" "uuid", "p_order_number" "text", "p_photos" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_client_request_legacy_json"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  legacy jsonb;
begin
  legacy := jsonb_strip_nulls(jsonb_build_object(
    'id', new.id,
    'sourceCollection', 'Client_Custom_Requests',
    'orderNumber', new.order_number,
    'requestNumber', new.request_number,
    'clientRequestNumber', new.client_request_number,
    'requestType', new.request_type,
    'orderType', new.order_type,
    'status', new.status,
    'clientStatus', new.client_status,
    'artistStatus', new.artist_status,
    'clientId', new.client_id,
    'clientUid', coalesce(new.client_uid, new.client_id),
    'clientEmail', new.client_email,
    'clientName', new.client_name,
    'selectedArtist', new.selected_artist,
    'selectedArtistEmail', new.selected_artist_email,
    'artistName', new.artist_name,
    'artistEmail', new.artist_email,
    'needBy', new.need_by,
    'needByDisplay', new.need_by_display,
    'description', new.description,
    'descriptionPreview', new.description_preview,
    'budgetMin', new.budget_min,
    'budgetMax', new.budget_max,
    'nailShape', new.nail_shape,
    'nailLength', new.nail_length,
    'nailPreferences', new.nail_preferences,
    'shipping', new.shipping,
    'inspirationPhotos', new.inspiration_photos,
    'photoCount', new.photo_count,
    'hasInspirationPhotos', new.has_inspiration_photos,
    'isDirectRequest', new.is_direct_request,
    'createdAt', new.created_at,
    'updatedAt', new.updated_at
  ));

  new.summary := coalesce(new.summary, '{}'::jsonb) || legacy;
  new.details := coalesce(new.details, '{}'::jsonb) || legacy;
  new.payload := coalesce(new.payload, '{}'::jsonb) || legacy;
  new.request_details := coalesce(new.request_details, '{}'::jsonb) || legacy;

  return new;
end;
$$;


ALTER FUNCTION "public"."sync_client_request_legacy_json"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_notifications" (
    "id" "text" DEFAULT ("gen_random_uuid"())::"text" NOT NULL,
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "type" "text",
    "source" "text",
    "request_id" "text",
    "title" "text",
    "message" "text",
    "client_name" "text",
    "brand_name" "text",
    "artist_name" "text",
    "campaign_name" "text",
    "registered_name" "text",
    "date_label" "text",
    "event_at" timestamp with time zone,
    "expires_at" timestamp with time zone,
    "read_at" timestamp with time zone,
    "payload" "jsonb" DEFAULT '{}'::"jsonb",
    "is_direct_to_artist" boolean DEFAULT false,
    "amount_label" "text",
    "courier_label" "text"
);


ALTER TABLE "public"."admin_notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "email" "text" NOT NULL,
    "full_name" "text",
    "role" "text" DEFAULT 'employee'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."admin_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."artist" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "account_type" "text",
    "profile" "jsonb",
    "services" "jsonb",
    "pricing" "jsonb",
    "availability" "jsonb",
    "portfolio" "jsonb",
    "credentials" "jsonb",
    "bundle" "jsonb",
    "payout" "jsonb",
    "agreements" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "panel_status" "text",
    "panel_display_name" "text",
    "panel_name" "text",
    "panel_instagram" "text",
    "panel_tiktok" "text",
    "is_blocked" boolean DEFAULT false,
    "blocked" boolean DEFAULT false,
    "deleted_at" timestamp with time zone,
    "admin_notes" "text",
    "admin" "jsonb" DEFAULT '{}'::"jsonb",
    "ascension" "jsonb" DEFAULT '{}'::"jsonb",
    "social_metrics" "jsonb" DEFAULT '{}'::"jsonb",
    "stats" "jsonb" DEFAULT '{}'::"jsonb",
    "metrics" "jsonb" DEFAULT '{}'::"jsonb",
    "earnings" "jsonb" DEFAULT '{}'::"jsonb",
    "portfolio_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "panel_portfolio_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "panel_artist_portfolio_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "portfolio_items" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "artist" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "displayname" "text",
    "name" "text",
    "studioname" "text",
    "bio" "text",
    "city" "text",
    "state" "text",
    "country" "text",
    "instagram" "text",
    "tiktok" "text",
    "profileimageurl" "text",
    "photourl" "text",
    "avatarurl" "text",
    "uid" "text",
    "roles" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "panel_studio_name" "text",
    "panel_language_spoken" "text",
    "panel_currency" "text",
    "panel_phone" "text",
    "panel_phone_area_code" "text",
    "panel_phone_local" "text",
    "panel_bio" "text",
    "panel_time_zone" "text",
    "panel_city" "text",
    "panel_state" "text",
    "panel_country" "text",
    "panel_address_line1" "text",
    "panel_address_city" "text",
    "panel_address_line2" "text",
    "panel_zip" "text",
    "panel_is_shipping_address_same" boolean,
    "panel_shipping_address_line1" "text",
    "panel_shipping_address_line2" "text",
    "panel_shipping_city" "text",
    "panel_shipping_state" "text",
    "panel_shipping_zip" "text",
    "panel_shipping_country" "text",
    "panel_shipping_time_zone" "text",
    "panel_nail_tech_type" "text",
    "panel_services" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "panel_min_price" "text",
    "panel_max_price" "text",
    "panel_rush_available" boolean,
    "panel_direct_requests_enabled" boolean,
    "panel_direct_request_year" integer,
    "panel_blocked_dates" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "panel_project_notes" "text",
    "panel_portfolio_link" "text",
    "panel_portfolio_image_count" integer,
    "panel_license_number" "text",
    "panel_jurisdiction" "text",
    "panel_pro_years_experience" "text",
    "panel_school" "text",
    "panel_practice_duration" "text",
    "panel_selected_bundle" "text",
    "panel_bundle_purchased" boolean,
    "panel_bundle_payment_saved" boolean,
    "panel_bundle_payment_method" "text",
    "panel_bundle_paypal_email" "text",
    "panel_bundle_venmo_handle" "text",
    "panel_payout" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "panel_payout_method" "text",
    "panel_payout_legal_name" "text",
    "panel_payout_email" "text",
    "panel_profile_image_url" "text",
    "panel_agree_terms" boolean,
    "panel_no_copyright" boolean,
    "panel_agree_safety" boolean,
    "panel_receive_updates" boolean,
    "photo_url" "text",
    "avatar_url" "text",
    "language_spoken" "text",
    "currency" "text",
    "payment" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "nail_preferences" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "address" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "client" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "direct_requests_enabled" boolean,
    "nfc_request_enabled" boolean,
    "all_client_request_notifications_enabled" boolean,
    "rating" numeric,
    "average_rating" numeric,
    "review_count" integer,
    "reviews" integer,
    "panel_rating" numeric,
    "panel_reviews" integer,
    "avatarUrl" "text",
    "displayName" "text",
    "profileImageUrl" "text",
    "photoUrl" "text",
    "nameOrStudio" "text",
    "fullName" "text",
    "panel_displayName" "text",
    "panel_fullName" "text",
    "panel_email" "text",
    "panel_profileImageUrl" "text",
    "studioName" "text",
    "profilePhotoUrl" "text",
    "panel_nameOrStudio" "text",
    "basic" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."artist" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."artist_portfolio_items" (
    "id" "text" NOT NULL,
    "image_url" "text",
    "storage_path" "text",
    "style" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."artist_portfolio_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."artists" (
    "id" "uuid" NOT NULL,
    "display_name" "text" NOT NULL,
    "bio" "text",
    "instagram_handle" "text",
    "tiktok_handle" "text",
    "profile_image_url" "text",
    "payout_method" "text",
    "tech_type" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ascension_level" "text" DEFAULT 'Maker'::"text",
    "ascension_points" integer DEFAULT 0,
    "completed_orders" integer DEFAULT 0,
    "artist_rating" numeric DEFAULT 0,
    "insurance_verified" boolean DEFAULT false,
    "sponsorship_eligible" boolean DEFAULT false,
    "ascension_override" boolean DEFAULT false,
    "ascension_notes" "text",
    "ascension_updated_at" timestamp with time zone,
    "ascension_updated_by" "uuid"
);


ALTER TABLE "public"."artists" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ascension_audit_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "artist_doc_path" "text",
    "artist_id" "text",
    "artist_email" "text" NOT NULL,
    "artist_name" "text",
    "previous_points" integer,
    "new_points" integer,
    "new_tier" "text",
    "sponsorship_eligible" boolean,
    "source" "text" DEFAULT 'auto_sync'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "artist_doc_id" "uuid",
    "event_type" "text",
    "delta" integer,
    "old_points" integer,
    "old_tier" "text",
    "reason" "text",
    "created_by" "text",
    "payload" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."ascension_audit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ascension_current" (
    "id" "text" NOT NULL,
    "artist_doc_path" "text",
    "artist_id" "text",
    "artist_email" "text" NOT NULL,
    "artist_name" "text",
    "ascension" "jsonb",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ascension_current" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ascension_overrides" (
    "id" "text" NOT NULL,
    "artist_email" "text",
    "artist_doc_path" "text",
    "artist_doc_path_lower" "text",
    "active" boolean DEFAULT true,
    "level_name" "text",
    "tier" "text",
    "level" "text",
    "tier_name" "text",
    "sponsorship_tier" "text",
    "points" integer,
    "sponsorship_eligible" boolean,
    "reason" "text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "artist_doc_id" "uuid",
    "artist_id" "text",
    "artist_name" "text",
    "override_tier" "text",
    "override_points" integer,
    "updated_by" "text",
    "cleared_by" "text",
    "payload" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."ascension_overrides" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."auth_email_aliases" (
    "id" "text" NOT NULL,
    "login_email" "text",
    "auth_email" "text",
    "uid" "text",
    "updated_at" timestamp with time zone
);


ALTER TABLE "public"."auth_email_aliases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."brand_notifications" (
    "id" "text" NOT NULL,
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."brand_notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."chat_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "room_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "image_url" "text",
    "is_read" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."chat_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."chat_rooms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "uuid" NOT NULL,
    "artist_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_message_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."chat_rooms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "account_type" "text",
    "profile" "jsonb",
    "basic" "jsonb",
    "address" "jsonb",
    "payment" "jsonb",
    "nail_preferences" "jsonb",
    "registration" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "panel_status" "text",
    "panel_display_name" "text",
    "panel_name" "text",
    "panel_email" "text",
    "panel_phone" "text",
    "panel_instagram" "text",
    "panel_tiktok" "text",
    "account_status" "text" DEFAULT 'Active'::"text",
    "is_blocked" boolean DEFAULT false,
    "blocked" boolean DEFAULT false,
    "deleted_at" timestamp with time zone,
    "admin_notes" "jsonb" DEFAULT '[]'::"jsonb",
    "assigned_support" "text",
    "assigned_support_email" "text",
    "support_assigned_at" timestamp with time zone,
    "admin" "jsonb" DEFAULT '{}'::"jsonb",
    "ascension" "jsonb" DEFAULT '{}'::"jsonb",
    "social_metrics" "jsonb" DEFAULT '{}'::"jsonb",
    "stats" "jsonb" DEFAULT '{}'::"jsonb",
    "metrics" "jsonb" DEFAULT '{}'::"jsonb",
    "billing" "jsonb" DEFAULT '{}'::"jsonb",
    "measurements" "jsonb" DEFAULT '{}'::"jsonb",
    "communication_preferences" "jsonb" DEFAULT '{}'::"jsonb",
    "nfc_selections" "jsonb" DEFAULT '{}'::"jsonb",
    "eligible_for_nfc" boolean DEFAULT false,
    "nfc_eligible" boolean DEFAULT false,
    "support_assignment" "jsonb" DEFAULT '{}'::"jsonb",
    "admin_note_count" integer DEFAULT 0,
    "latest_admin_note" "text",
    "latest_admin_note_at" timestamp with time zone,
    "summary" "jsonb" DEFAULT '{}'::"jsonb",
    "updated_by" "text",
    "portfolio_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "panel_portfolio_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "panel_artist_portfolio_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "portfolio_items" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "portfolio" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "client" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "nfc_smart_nail_profile" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."client" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_artist" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "account_type" "text" DEFAULT 'client_artist'::"text",
    "profile" "jsonb",
    "address" "jsonb",
    "payment" "jsonb",
    "nail_preferences" "jsonb",
    "artist_profile" "jsonb",
    "services" "jsonb",
    "pricing" "jsonb",
    "availability" "jsonb",
    "portfolio" "jsonb",
    "credentials" "jsonb",
    "bundle" "jsonb",
    "payout" "jsonb",
    "agreements" "jsonb",
    "registration" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "panel_status" "text",
    "panel_display_name" "text",
    "panel_name" "text",
    "panel_instagram" "text",
    "panel_tiktok" "text",
    "is_blocked" boolean DEFAULT false,
    "blocked" boolean DEFAULT false,
    "deleted_at" timestamp with time zone,
    "admin_notes" "text",
    "admin" "jsonb" DEFAULT '{}'::"jsonb",
    "ascension" "jsonb" DEFAULT '{}'::"jsonb",
    "social_metrics" "jsonb" DEFAULT '{}'::"jsonb",
    "stats" "jsonb" DEFAULT '{}'::"jsonb",
    "metrics" "jsonb" DEFAULT '{}'::"jsonb",
    "earnings" "jsonb" DEFAULT '{}'::"jsonb",
    "panel_email" "text",
    "panel_phone" "text",
    "account_status" "text" DEFAULT 'Active'::"text",
    "assigned_support" "text",
    "assigned_support_email" "text",
    "support_assigned_at" timestamp with time zone,
    "billing" "jsonb" DEFAULT '{}'::"jsonb",
    "measurements" "jsonb" DEFAULT '{}'::"jsonb",
    "communication_preferences" "jsonb" DEFAULT '{}'::"jsonb",
    "nfc_selections" "jsonb" DEFAULT '{}'::"jsonb",
    "eligible_for_nfc" boolean DEFAULT false,
    "nfc_eligible" boolean DEFAULT false,
    "support_assignment" "jsonb" DEFAULT '{}'::"jsonb",
    "admin_note_count" integer DEFAULT 0,
    "latest_admin_note" "text",
    "latest_admin_note_at" timestamp with time zone,
    "summary" "jsonb" DEFAULT '{}'::"jsonb",
    "updated_by" "text",
    "portfolio_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "panel_portfolio_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "panel_artist_portfolio_images" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "portfolio_items" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "client" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "artist" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "displayname" "text",
    "name" "text",
    "studioname" "text",
    "bio" "text",
    "city" "text",
    "state" "text",
    "country" "text",
    "instagram" "text",
    "tiktok" "text",
    "profileimageurl" "text",
    "photourl" "text",
    "avatarurl" "text",
    "uid" "text",
    "direct_requests_enabled" boolean,
    "nfc_request_enabled" boolean,
    "all_client_request_notifications_enabled" boolean,
    "nfc_smart_nail_profile" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "rating" numeric,
    "average_rating" numeric,
    "review_count" integer,
    "reviews" integer,
    "panel_rating" numeric,
    "panel_reviews" integer,
    "avatarUrl" "text",
    "displayName" "text",
    "profileImageUrl" "text",
    "photoUrl" "text",
    "nameOrStudio" "text",
    "fullName" "text",
    "panel_displayName" "text",
    "panel_fullName" "text",
    "panel_profileImageUrl" "text",
    "studioName" "text",
    "profilePhotoUrl" "text",
    "panel_nameOrStudio" "text",
    "basic" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."client_artist" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_artist_portfolio_items" (
    "id" "text" NOT NULL,
    "image_url" "text",
    "storage_path" "text",
    "style" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."client_artist_portfolio_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_artist_registration_drafts" (
    "draft_id" "text" NOT NULL,
    "user_id" "uuid",
    "email" "text",
    "name" "text",
    "phone" "text",
    "current_step" integer,
    "current_step_key" "text",
    "status" "text" DEFAULT 'draft'::"text",
    "profile_image_url" "text",
    "portfolio_images" "jsonb" DEFAULT '[]'::"jsonb",
    "payload" "jsonb" DEFAULT '{}'::"jsonb",
    "step_payload" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "completed_at" timestamp with time zone
);


ALTER TABLE "public"."client_artist_registration_drafts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_custom_requests_details" (
    "id" "text" DEFAULT "gen_random_uuid"() NOT NULL,
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "request_id" "uuid",
    "detail_key" "text" DEFAULT 'payload'::"text"
);


ALTER TABLE "public"."client_custom_requests_details" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "auth_user_id" "uuid",
    "client_id" "text",
    "name" "text",
    "email" "text",
    "phone" "text",
    "instagram" "text",
    "tiktok" "text",
    "location" "text",
    "account_type" "text" DEFAULT 'client'::"text",
    "is_client" boolean DEFAULT true,
    "is_artist" boolean DEFAULT false,
    "is_blocked" boolean DEFAULT false,
    "is_nfc_eligible" boolean DEFAULT false,
    "ascension_status" "text" DEFAULT 'not_eligible'::"text",
    "total_followers" integer DEFAULT 0,
    "completed_orders" integer DEFAULT 0,
    "total_spend" numeric DEFAULT 0,
    "profile" "jsonb" DEFAULT '{}'::"jsonb",
    "social_metrics" "jsonb" DEFAULT '{}'::"jsonb",
    "nail_preferences" "jsonb" DEFAULT '{}'::"jsonb",
    "payments" "jsonb" DEFAULT '{}'::"jsonb",
    "admin_notes" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."clients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."company" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "account_type" "text" DEFAULT 'company'::"text",
    "profile" "jsonb",
    "basic" "jsonb",
    "company" "jsonb",
    "addresses" "jsonb",
    "billing" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "panel_logo_url" "text",
    "panel_profile_image_url" "text",
    "company_logo_url" "text",
    "brand_logo_url" "text",
    "logo_url" "text",
    "profile_image_url" "text",
    "photo_url" "text",
    "avatar_url" "text",
    "panel_company_name" "text",
    "panel_contact_name" "text",
    "panel_contact_email" "text",
    "panel_company_phone" "text",
    "panel_contact_phone" "text",
    "panel_company_website" "text",
    "panel_business_type" "text",
    "panel_billing_method" "text",
    "panel_billing_save_for_future_use" boolean,
    "panel_billing_name_on_card" "text",
    "panel_billing_expiry" "text",
    "panel_billing_apple_pay_email" "text",
    "panel_billing_google_pay_email" "text",
    "panel_billing_street" "text",
    "panel_billing_city" "text",
    "panel_billing_state" "text",
    "panel_billing_zip" "text",
    "panel_billing_country" "text",
    "panel_shipping_same_as_billing" boolean,
    "panel_shipping_street" "text",
    "panel_shipping_city" "text",
    "panel_shipping_state" "text",
    "panel_shipping_zip" "text",
    "panel_shipping_country" "text",
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "status" "text" DEFAULT 'active'::"text",
    "admin_status" "text" DEFAULT 'active'::"text",
    "admin_action" "text",
    "admin_action_reason" "text",
    "admin_action_by" "text",
    "admin_action_at" timestamp with time zone,
    "admin" "jsonb" DEFAULT '{}'::"jsonb",
    "brand_id" "text",
    "panel_brand_id" "text",
    "is_blocked" boolean DEFAULT false,
    "blocked" boolean DEFAULT false,
    "account_status" "text" DEFAULT 'active'::"text",
    "company_name" "text",
    "brand_name" "text",
    "campaign_name" "text"
);


ALTER TABLE "public"."company" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."company_custom_requests_details" (
    "id" "text" DEFAULT "gen_random_uuid"() NOT NULL,
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "request_id" "uuid",
    "detail_key" "text" DEFAULT 'payload'::"text"
);


ALTER TABLE "public"."company_custom_requests_details" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mail_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "to_email" "text",
    "to_list" "jsonb" DEFAULT '[]'::"jsonb",
    "subject" "text",
    "text" "text",
    "html" "text",
    "template_name" "text",
    "template_data" "jsonb" DEFAULT '{}'::"jsonb",
    "status" "text" DEFAULT 'queued'::"text",
    "payload" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "processed_at" timestamp with time zone
);


ALTER TABLE "public"."mail_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."portfolio_items" (
    "id" "text" NOT NULL,
    "image_url" "text",
    "url" "text",
    "image" "text",
    "style" "text",
    "storage_path" "text",
    "source" "text",
    "request_id" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."portfolio_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."request_chat_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "text",
    "request_id" "uuid",
    "text" "text",
    "sender_email" "text",
    "sender_name" "text",
    "attachment_url" "text",
    "attachment_type" "text",
    "attachment_name" "text",
    "is_system" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_at_ms" bigint,
    "client_email" "text",
    "artist_email" "text",
    "client_name" "text",
    "artist_name" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."request_chat_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."request_chats" (
    "id" "text" NOT NULL,
    "request_id" "uuid",
    "client_email" "text",
    "artist_email" "text",
    "client_name" "text",
    "artist_name" "text",
    "participants" "jsonb" DEFAULT '[]'::"jsonb",
    "last_message" "text",
    "last_sender_email" "text",
    "last_sender_name" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "created_at_ms" bigint,
    "updated_at_ms" bigint,
    "conversation_id" "text",
    "last_message_at" timestamp with time zone
);


ALTER TABLE "public"."request_chats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" "text" NOT NULL,
    "order_id" "text",
    "artist_id" "text",
    "rating" integer,
    "comment" "text",
    "created_at" timestamp with time zone,
    "data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sms_outbox" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "to_number" "text",
    "message" "text",
    "status" "text" DEFAULT 'queued'::"text",
    "payload" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "processed_at" timestamp with time zone
);


ALTER TABLE "public"."sms_outbox" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tip_payout_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "text",
    "order_number" "text",
    "source_collection" "text",
    "artist_email" "text",
    "artist_name" "text",
    "client_email" "text",
    "tip_amount" numeric,
    "tip_percent" numeric,
    "custom_tip_amount" numeric,
    "funding_source" "text",
    "status" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tip_payout_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tips" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "text" NOT NULL,
    "artist_id" "text" NOT NULL,
    "created_by_uid" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "tip_percent" integer NOT NULL,
    "tip_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'pending_payment'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."tips" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "receiver_email" "text",
    "title" "text",
    "body" "text",
    "type" "text",
    "order_id" "text",
    "order_number" "text",
    "source_collection" "text",
    "read" boolean DEFAULT false,
    "extra" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_at_millis" bigint,
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_notifications" OWNER TO "postgres";


ALTER TABLE ONLY "public"."admin_notifications"
    ADD CONSTRAINT "admin_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."artist"
    ADD CONSTRAINT "artist_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."artist_portfolio_items"
    ADD CONSTRAINT "artist_portfolio_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."artists"
    ADD CONSTRAINT "artists_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ascension_audit_logs"
    ADD CONSTRAINT "ascension_audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ascension_current"
    ADD CONSTRAINT "ascension_current_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ascension_overrides"
    ADD CONSTRAINT "ascension_overrides_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."auth_email_aliases"
    ADD CONSTRAINT "auth_email_aliases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."brand_notifications"
    ADD CONSTRAINT "brand_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chat_messages"
    ADD CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chat_rooms"
    ADD CONSTRAINT "chat_rooms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_artist"
    ADD CONSTRAINT "client_artist_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_artist_portfolio_items"
    ADD CONSTRAINT "client_artist_portfolio_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_artist_registration_drafts"
    ADD CONSTRAINT "client_artist_registration_drafts_pkey" PRIMARY KEY ("draft_id");



ALTER TABLE ONLY "public"."client_custom_requests_details"
    ADD CONSTRAINT "client_custom_requests_details_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_custom_requests"
    ADD CONSTRAINT "client_custom_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client"
    ADD CONSTRAINT "client_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_client_id_key" UNIQUE ("client_id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."company_custom_requests_details"
    ADD CONSTRAINT "company_custom_requests_details_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."company_custom_requests"
    ADD CONSTRAINT "company_custom_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."company"
    ADD CONSTRAINT "company_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mail_queue"
    ADD CONSTRAINT "mail_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."portfolio_items"
    ADD CONSTRAINT "portfolio_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."request_chat_messages"
    ADD CONSTRAINT "request_chat_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."request_chats"
    ADD CONSTRAINT "request_chats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sms_outbox"
    ADD CONSTRAINT "sms_outbox_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tip_payout_queue"
    ADD CONSTRAINT "tip_payout_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tips"
    ADD CONSTRAINT "tips_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chat_rooms"
    ADD CONSTRAINT "unique_client_artist_room" UNIQUE ("client_id", "artist_id");



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_pkey" PRIMARY KEY ("id");



CREATE INDEX "ascension_audit_created_at_idx" ON "public"."ascension_audit_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "ascension_audit_email_created_idx" ON "public"."ascension_audit_logs" USING "btree" ("artist_email", "created_at" DESC);



CREATE INDEX "ascension_audit_email_idx" ON "public"."ascension_audit_logs" USING "btree" ("artist_email");



CREATE INDEX "ascension_current_email_idx" ON "public"."ascension_current" USING "btree" ("artist_email");



CREATE INDEX "ascension_overrides_active_idx" ON "public"."ascension_overrides" USING "btree" ("active") WHERE ("active" = true);



CREATE INDEX "ascension_overrides_doc_path_lower_idx" ON "public"."ascension_overrides" USING "btree" ("artist_doc_path_lower");



CREATE INDEX "ascension_overrides_email_idx" ON "public"."ascension_overrides" USING "btree" ("artist_email");



CREATE INDEX "auth_email_aliases_auth_email_idx" ON "public"."auth_email_aliases" USING "btree" ("auth_email");



CREATE INDEX "auth_email_aliases_uid_idx" ON "public"."auth_email_aliases" USING "btree" ("uid");



CREATE INDEX "idx_admin_notifications_event_at" ON "public"."admin_notifications" USING "btree" ("event_at" DESC);



CREATE INDEX "idx_admin_notifications_read_at" ON "public"."admin_notifications" USING "btree" ("read_at");



CREATE INDEX "idx_admin_notifications_type_source_request" ON "public"."admin_notifications" USING "btree" ("type", "source", "request_id");



CREATE INDEX "idx_ascension_audit_logs_artist_id" ON "public"."ascension_audit_logs" USING "btree" ("artist_id");



CREATE INDEX "idx_ascension_audit_logs_created_at" ON "public"."ascension_audit_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_ascension_overrides_active" ON "public"."ascension_overrides" USING "btree" ("active");



CREATE INDEX "idx_ascension_overrides_artist_doc_id" ON "public"."ascension_overrides" USING "btree" ("artist_doc_id");



CREATE INDEX "idx_chat_messages_room_time" ON "public"."chat_messages" USING "btree" ("room_id", "created_at" DESC);



CREATE INDEX "idx_client_custom_requests_accepted_artist_email" ON "public"."client_custom_requests" USING "btree" ("lower"("accepted_by_artist_email"));



CREATE INDEX "idx_client_custom_requests_artist_email" ON "public"."client_custom_requests" USING "btree" ("lower"("artist_email"));



CREATE INDEX "idx_client_custom_requests_artist_status" ON "public"."client_custom_requests" USING "btree" ("artist_status");



CREATE INDEX "idx_client_custom_requests_client_email" ON "public"."client_custom_requests" USING "btree" ("lower"("client_email"));



CREATE INDEX "idx_client_custom_requests_client_id" ON "public"."client_custom_requests" USING "btree" ("client_id");



CREATE INDEX "idx_client_custom_requests_client_status" ON "public"."client_custom_requests" USING "btree" ("client_status");



CREATE INDEX "idx_client_custom_requests_client_uid" ON "public"."client_custom_requests" USING "btree" ("client_uid");



CREATE INDEX "idx_client_custom_requests_created_at" ON "public"."client_custom_requests" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_client_custom_requests_details_request_id" ON "public"."client_custom_requests_details" USING "btree" ("request_id");



CREATE INDEX "idx_client_custom_requests_need_by" ON "public"."client_custom_requests" USING "btree" ("need_by");



CREATE INDEX "idx_client_custom_requests_order_number" ON "public"."client_custom_requests" USING "btree" ("order_number");



CREATE INDEX "idx_client_custom_requests_selected_artist_email" ON "public"."client_custom_requests" USING "btree" ("lower"("selected_artist_email"));



CREATE INDEX "idx_client_custom_requests_status" ON "public"."client_custom_requests" USING "btree" ("lower"("status"));



CREATE INDEX "idx_client_custom_requests_updated_at" ON "public"."client_custom_requests" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_company_admin_status" ON "public"."company" USING "btree" ("lower"("admin_status"));



CREATE INDEX "idx_company_custom_requests_accepted_artist_email" ON "public"."company_custom_requests" USING "btree" ("lower"("accepted_by_artist_email"));



CREATE INDEX "idx_company_custom_requests_accepted_client_email" ON "public"."company_custom_requests" USING "btree" ("lower"("accepted_by_client_email"));



CREATE INDEX "idx_company_custom_requests_cancelled_at" ON "public"."company_custom_requests" USING "btree" ("cancelled_at");



CREATE INDEX "idx_company_custom_requests_client_email" ON "public"."company_custom_requests" USING "btree" ("lower"("client_email"));



CREATE INDEX "idx_company_custom_requests_client_rating" ON "public"."company_custom_requests" USING "btree" ("client_rating");



CREATE INDEX "idx_company_custom_requests_company_email" ON "public"."company_custom_requests" USING "btree" ("lower"("company_email"));



CREATE INDEX "idx_company_custom_requests_company_uid" ON "public"."company_custom_requests" USING "btree" ("company_uid");



CREATE INDEX "idx_company_custom_requests_created_at" ON "public"."company_custom_requests" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_company_custom_requests_need_by" ON "public"."company_custom_requests" USING "btree" ("need_by");



CREATE INDEX "idx_company_custom_requests_order_number" ON "public"."company_custom_requests" USING "btree" ("order_number");



CREATE INDEX "idx_company_custom_requests_review_submitted" ON "public"."company_custom_requests" USING "btree" ("client_review_submitted_at");



CREATE INDEX "idx_company_custom_requests_selected_artist_email" ON "public"."company_custom_requests" USING "btree" ("lower"("selected_artist_email"));



CREATE INDEX "idx_company_custom_requests_selected_client_email" ON "public"."company_custom_requests" USING "btree" ("lower"("selected_client_email"));



CREATE INDEX "idx_company_custom_requests_status" ON "public"."company_custom_requests" USING "btree" ("lower"("status"));



CREATE INDEX "idx_company_status" ON "public"."company" USING "btree" ("lower"("status"));



CREATE INDEX "idx_request_chat_messages_conversation" ON "public"."request_chat_messages" USING "btree" ("conversation_id");



CREATE INDEX "idx_request_chat_messages_conversation_id" ON "public"."request_chat_messages" USING "btree" ("conversation_id");



CREATE INDEX "idx_request_chat_messages_created" ON "public"."request_chat_messages" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_request_chat_messages_created_at" ON "public"."request_chat_messages" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_request_chats_conversation_id" ON "public"."request_chats" USING "btree" ("conversation_id");



CREATE INDEX "idx_user_notifications_order_type" ON "public"."user_notifications" USING "btree" ("order_id", "order_number", "type");



CREATE INDEX "idx_user_notifications_receiver_read_created" ON "public"."user_notifications" USING "btree" ("lower"("receiver_email"), "read", "created_at" DESC);



CREATE INDEX "portfolio_items_request_id_idx" ON "public"."portfolio_items" USING "btree" ("request_id");



CREATE INDEX "reviews_artist_id_idx" ON "public"."reviews" USING "btree" ("artist_id");



CREATE INDEX "reviews_order_id_idx" ON "public"."reviews" USING "btree" ("order_id");



CREATE INDEX "tip_payout_queue_artist_email_idx" ON "public"."tip_payout_queue" USING "btree" ("artist_email");



CREATE INDEX "tip_payout_queue_order_id_idx" ON "public"."tip_payout_queue" USING "btree" ("order_id");



CREATE INDEX "tips_artist_id_idx" ON "public"."tips" USING "btree" ("artist_id");



CREATE INDEX "tips_created_at_idx" ON "public"."tips" USING "btree" ("created_at" DESC);



CREATE INDEX "tips_created_by_uid_idx" ON "public"."tips" USING "btree" ("created_by_uid");



CREATE INDEX "tips_order_id_idx" ON "public"."tips" USING "btree" ("order_id");



CREATE OR REPLACE TRIGGER "trg_client_request_before_save_defaults" BEFORE INSERT ON "public"."client_custom_requests" FOR EACH ROW EXECUTE FUNCTION "public"."client_request_before_save_defaults"();



CREATE OR REPLACE TRIGGER "trg_notify_admin_client_artist_registered" AFTER INSERT ON "public"."client_artist" FOR EACH ROW EXECUTE FUNCTION "public"."notify_admin_client_registered"();



CREATE OR REPLACE TRIGGER "trg_notify_admin_client_registered" AFTER INSERT ON "public"."client" FOR EACH ROW EXECUTE FUNCTION "public"."notify_admin_client_registered"();



CREATE OR REPLACE TRIGGER "trg_notify_admin_client_request_created" AFTER INSERT ON "public"."client_custom_requests" FOR EACH ROW EXECUTE FUNCTION "public"."notify_admin_client_request_created"();



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."artists"
    ADD CONSTRAINT "artists_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_messages"
    ADD CONSTRAINT "chat_messages_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "public"."chat_rooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_messages"
    ADD CONSTRAINT "chat_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_rooms"
    ADD CONSTRAINT "chat_rooms_artist_id_fkey" FOREIGN KEY ("artist_id") REFERENCES "public"."artists"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_rooms"
    ADD CONSTRAINT "chat_rooms_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."request_chat_messages"
    ADD CONSTRAINT "request_chat_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."request_chats"("id") ON DELETE CASCADE;



CREATE POLICY "Admins and brands can read company requests" ON "public"."company_custom_requests" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true)))) OR ("company_uid" = "auth"."uid"()) OR ("lower"("company_email") = "lower"(("auth"."jwt"() ->> 'email'::"text")))));



CREATE POLICY "Admins and brands can update company requests" ON "public"."company_custom_requests" FOR UPDATE TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true)))) OR ("company_uid" = "auth"."uid"()) OR ("lower"("company_email") = "lower"(("auth"."jwt"() ->> 'email'::"text"))))) WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true)))) OR ("company_uid" = "auth"."uid"()) OR ("lower"("company_email") = "lower"(("auth"."jwt"() ->> 'email'::"text")))));



CREATE POLICY "Admins can read artist ascension" ON "public"."artist" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true)))));



CREATE POLICY "Admins can read client artist ascension" ON "public"."client_artist" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true)))));



CREATE POLICY "Admins can read company" ON "public"."company" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true)))));



CREATE POLICY "Admins can read company custom requests" ON "public"."company_custom_requests" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true)))));



CREATE POLICY "Admins can update artist ascension" ON "public"."artist" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true)))));



CREATE POLICY "Admins can update client artist ascension" ON "public"."client_artist" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true)))));



CREATE POLICY "Admins can update company custom requests" ON "public"."company_custom_requests" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE (("admin_users"."id" = "auth"."uid"()) AND ("admin_users"."is_active" = true)))));



CREATE POLICY "Allow artists to update their own profile" ON "public"."artists" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Allow public read access to artist profiles" ON "public"."artists" FOR SELECT USING (true);



CREATE POLICY "Allow public read access to client profiles" ON "public"."clients" FOR SELECT USING (true);



CREATE POLICY "Allow users to create chat rooms they participate in" ON "public"."chat_rooms" FOR INSERT WITH CHECK ((("auth"."uid"() = "client_id") OR ("auth"."uid"() = "artist_id")));



CREATE POLICY "Allow users to insert messages in their rooms" ON "public"."chat_messages" FOR INSERT WITH CHECK ((("auth"."uid"() = "sender_id") AND (EXISTS ( SELECT 1
   FROM "public"."chat_rooms"
  WHERE (("chat_rooms"."id" = "chat_messages"."room_id") AND (("chat_rooms"."client_id" = "auth"."uid"()) OR ("chat_rooms"."artist_id" = "auth"."uid"())))))));



CREATE POLICY "Allow users to read messages in their rooms" ON "public"."chat_messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."chat_rooms"
  WHERE (("chat_rooms"."id" = "chat_messages"."room_id") AND (("chat_rooms"."client_id" = "auth"."uid"()) OR ("chat_rooms"."artist_id" = "auth"."uid"()))))));



CREATE POLICY "Allow users to update their own client profile" ON "public"."clients" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Allow users to view chat rooms they belong to" ON "public"."chat_rooms" FOR SELECT USING ((("auth"."uid"() = "client_id") OR ("auth"."uid"() = "artist_id")));



CREATE POLICY "Employees can read own profile" ON "public"."admin_users" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));



ALTER TABLE "public"."admin_notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."admin_users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "admins insert admin notifications" ON "public"."admin_notifications" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins manage ascension audit logs" ON "public"."ascension_audit_logs" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins manage ascension overrides" ON "public"."ascension_overrides" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read admin notifications" ON "public"."admin_notifications" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read artist rows" ON "public"."artist" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read artists" ON "public"."artist" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read brand requests page" ON "public"."company_custom_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read client artist rows" ON "public"."client_artist" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read client artist rows for clients" ON "public"."client_artist" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read client artists" ON "public"."client_artist" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read client custom requests" ON "public"."client_custom_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read client request rows for client details" ON "public"."client_custom_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read client requests page" ON "public"."client_custom_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read client rows" ON "public"."client" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read clients" ON "public"."client" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read company custom requests" ON "public"."company_custom_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read company rows" ON "public"."company" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read own admin row" ON "public"."admin_users" FOR SELECT USING ((("lower"("email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("is_active" = true)));



CREATE POLICY "admins read payments brand requests" ON "public"."company_custom_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read payments client requests" ON "public"."client_custom_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read reviews brand requests" ON "public"."company_custom_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read reviews client artists" ON "public"."client_artist" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read reviews client requests" ON "public"."client_custom_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins read reviews company requests" ON "public"."company_custom_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins update admin notifications" ON "public"."admin_notifications" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins update artist rows" ON "public"."artist" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins update brand requests page" ON "public"."company_custom_requests" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins update client artist rows" ON "public"."client_artist" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins update client artist rows for clients" ON "public"."client_artist" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins update client requests page" ON "public"."client_custom_requests" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins update client rows" ON "public"."client" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins update company custom requests" ON "public"."company_custom_requests" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



CREATE POLICY "admins update company rows" ON "public"."company" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "a"
  WHERE (("lower"("a"."email") = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))) AND ("a"."is_active" = true)))));



ALTER TABLE "public"."artist" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "artist insert own row" ON "public"."artist" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "artist public read" ON "public"."artist" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "artist read own row" ON "public"."artist" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "artist update own row" ON "public"."artist" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."artist_portfolio_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."artists" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "artists can read calendar requests" ON "public"."client_custom_requests" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "artists read client requests" ON "public"."client_custom_requests" FOR SELECT USING ((("auth"."uid"() IS NOT NULL) AND ((COALESCE("open_to_artist_pool", true) = true) OR ("lower"(COALESCE("selected_artist_email", "artist_email", "accepted_by_artist_email", ''::"text")) = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))))));



CREATE POLICY "artists read company requests" ON "public"."company_custom_requests" FOR SELECT USING ((("auth"."uid"() IS NOT NULL) AND ((COALESCE("open_to_artist_pool", true) = true) OR ("lower"(COALESCE("selected_artist_email", "artist_email", "accepted_by_artist_email", ''::"text")) = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text"))))));



CREATE POLICY "artists update client requests" ON "public"."client_custom_requests" FOR UPDATE USING ((("auth"."uid"() IS NOT NULL) AND ((COALESCE("open_to_artist_pool", true) = true) OR ("lower"(COALESCE("selected_artist_email", "artist_email", "accepted_by_artist_email", ''::"text")) = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")))))) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "artists update company requests" ON "public"."company_custom_requests" FOR UPDATE USING ((("auth"."uid"() IS NOT NULL) AND ((COALESCE("open_to_artist_pool", true) = true) OR ("lower"(COALESCE("selected_artist_email", "artist_email", "accepted_by_artist_email", ''::"text")) = "lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")))))) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "artists_read_own_ascension_current" ON "public"."ascension_current" FOR SELECT USING (("artist_email" = "auth"."email"()));



CREATE POLICY "artists_read_own_audit_logs" ON "public"."ascension_audit_logs" FOR SELECT USING (("artist_email" = "auth"."email"()));



CREATE POLICY "artists_read_own_overrides" ON "public"."ascension_overrides" FOR SELECT USING (("artist_email" = "auth"."email"()));



ALTER TABLE "public"."ascension_audit_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ascension_current" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ascension_overrides" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."auth_email_aliases" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "auth_email_aliases_insert_own" ON "public"."auth_email_aliases" FOR INSERT TO "authenticated" WITH CHECK (("uid" = ("auth"."uid"())::"text"));



CREATE POLICY "auth_email_aliases_select_public" ON "public"."auth_email_aliases" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "auth_email_aliases_update_own" ON "public"."auth_email_aliases" FOR UPDATE TO "authenticated" USING (("uid" = ("auth"."uid"())::"text")) WITH CHECK (("uid" = ("auth"."uid"())::"text"));



CREATE POLICY "authenticated can read client requests" ON "public"."client_custom_requests" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "authenticated can read company requests" ON "public"."company_custom_requests" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "authenticated can update company requests" ON "public"."company_custom_requests" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated insert admin notifications" ON "public"."admin_notifications" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated insert mail queue" ON "public"."mail_queue" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated insert sms outbox" ON "public"."sms_outbox" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated manage user notifications" ON "public"."user_notifications" USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated read client list" ON "public"."client" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated read clients list" ON "public"."clients" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated users can insert custom requests" ON "public"."client_custom_requests" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "authenticated users can read custom requests" ON "public"."client_custom_requests" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "authenticated users can update custom requests" ON "public"."client_custom_requests" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



ALTER TABLE "public"."brand_notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."chat_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."chat_rooms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."client" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "client artist public read" ON "public"."client_artist" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "client create own submitted requests" ON "public"."client_custom_requests" FOR INSERT WITH CHECK ((("auth"."uid"() = "client_id") OR ("auth"."uid"() = "client_uid") OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("client_email", ''::"text")))));



CREATE POLICY "client insert own row" ON "public"."client" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "client read own row" ON "public"."client" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "client read own submitted requests" ON "public"."client_custom_requests" FOR SELECT USING ((("auth"."uid"() = "client_id") OR ("auth"."uid"() = "client_uid") OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("client_email", ''::"text")))));



CREATE POLICY "client request details authenticated insert" ON "public"."client_custom_requests_details" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "client request details authenticated read" ON "public"."client_custom_requests_details" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "client request details authenticated update" ON "public"."client_custom_requests_details" FOR UPDATE USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "client update own row" ON "public"."client" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "client update own submitted requests" ON "public"."client_custom_requests" FOR UPDATE USING ((("auth"."uid"() = "client_id") OR ("auth"."uid"() = "client_uid") OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("client_email", ''::"text"))))) WITH CHECK ((("auth"."uid"() = "client_id") OR ("auth"."uid"() = "client_uid") OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("client_email", ''::"text")))));



ALTER TABLE "public"."client_artist" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "client_artist insert own row" ON "public"."client_artist" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "client_artist read own row" ON "public"."client_artist" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "client_artist update own row" ON "public"."client_artist" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."client_artist_portfolio_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."client_artist_registration_drafts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "client_artist_select_own_row" ON "public"."client_artist" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "client_artist_update_own_row" ON "public"."client_artist" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."client_custom_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."client_custom_requests_details" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "client_select_own_row" ON "public"."client" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "client_update_own_row" ON "public"."client" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."clients" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "clients can read active company profiles" ON "public"."company" FOR SELECT TO "authenticated" USING (((COALESCE("is_blocked", false) = false) AND (COALESCE("blocked", false) = false) AND ("lower"(COALESCE("account_status", "status", "admin_status", 'active'::"text")) = 'active'::"text")));



ALTER TABLE "public"."company" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "company create own requests" ON "public"."company_custom_requests" FOR INSERT WITH CHECK ((("auth"."uid"() = "company_uid") OR ("auth"."uid"() = "requester_uid") OR ("auth"."uid"() = "created_by_uid") OR ("auth"."uid"() = "uid")));



CREATE POLICY "company details update own brand requests" ON "public"."company_custom_requests" FOR UPDATE USING ((("auth"."uid"() = "company_uid") OR ("auth"."uid"() = "requester_uid") OR ("auth"."uid"() = "created_by_uid") OR ("auth"."uid"() = "uid") OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("company_email", ''::"text"))) OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("client_email", ''::"text"))) OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("selected_client_email", ''::"text"))))) WITH CHECK ((("auth"."uid"() = "company_uid") OR ("auth"."uid"() = "requester_uid") OR ("auth"."uid"() = "created_by_uid") OR ("auth"."uid"() = "uid") OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("company_email", ''::"text"))) OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("client_email", ''::"text"))) OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("selected_client_email", ''::"text")))));



CREATE POLICY "company insert own row" ON "public"."company" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "company read own requests" ON "public"."company_custom_requests" FOR SELECT USING ((("auth"."uid"() = "company_uid") OR ("auth"."uid"() = "requester_uid") OR ("auth"."uid"() = "created_by_uid") OR ("auth"."uid"() = "uid") OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("company_email", ''::"text"))) OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("client_email", ''::"text"))) OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("requester_email", ''::"text"))) OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("email", ''::"text")))));



CREATE POLICY "company read own row" ON "public"."company" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "company request details authenticated insert" ON "public"."company_custom_requests_details" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "company request details authenticated read" ON "public"."company_custom_requests_details" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "company request details authenticated update" ON "public"."company_custom_requests_details" FOR UPDATE USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "company update own brand requests" ON "public"."company_custom_requests" FOR UPDATE USING ((("auth"."uid"() = "company_uid") OR ("auth"."uid"() = "requester_uid") OR ("auth"."uid"() = "created_by_uid") OR ("auth"."uid"() = "uid") OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("company_email", ''::"text"))))) WITH CHECK ((("auth"."uid"() = "company_uid") OR ("auth"."uid"() = "requester_uid") OR ("auth"."uid"() = "created_by_uid") OR ("auth"."uid"() = "uid")));



CREATE POLICY "company update own requests" ON "public"."company_custom_requests" FOR UPDATE USING ((("auth"."uid"() = "company_uid") OR ("auth"."uid"() = "requester_uid") OR ("auth"."uid"() = "created_by_uid") OR ("auth"."uid"() = "uid") OR ("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("company_email", ''::"text"))))) WITH CHECK ((("auth"."uid"() = "company_uid") OR ("auth"."uid"() = "requester_uid") OR ("auth"."uid"() = "created_by_uid") OR ("auth"."uid"() = "uid")));



CREATE POLICY "company update own row" ON "public"."company" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."company_custom_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."company_custom_requests_details" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mail_queue" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."portfolio_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "request chat messages authenticated insert" ON "public"."request_chat_messages" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "request chat messages authenticated read" ON "public"."request_chat_messages" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "request chat messages authenticated update" ON "public"."request_chat_messages" FOR UPDATE USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "request chats authenticated insert" ON "public"."request_chats" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "request chats authenticated read" ON "public"."request_chats" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "request chats authenticated update" ON "public"."request_chats" FOR UPDATE USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



ALTER TABLE "public"."request_chat_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."request_chats" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "service_role_all_ascension_current" ON "public"."ascension_current" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_audit_logs" ON "public"."ascension_audit_logs" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_overrides" ON "public"."ascension_overrides" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."sms_outbox" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tip_payout_queue" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tip_payout_queue_insert_authenticated" ON "public"."tip_payout_queue" FOR INSERT TO "authenticated" WITH CHECK (true);



ALTER TABLE "public"."tips" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tips_insert_authenticated" ON "public"."tips" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() IS NOT NULL) AND ("created_by_uid" = "auth"."uid"())));



CREATE POLICY "tips_select_own_or_assigned_artist" ON "public"."tips" FOR SELECT TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("created_by_uid" = "auth"."uid"()) OR ("artist_id" = ("auth"."uid"())::"text"))));



ALTER TABLE "public"."user_notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users can read own client artist profile" ON "public"."client_artist" FOR SELECT TO "authenticated" USING ((("id" = "auth"."uid"()) OR ("lower"("email") = "lower"(("auth"."jwt"() ->> 'email'::"text")))));



CREATE POLICY "users can read own client profile" ON "public"."client" FOR SELECT TO "authenticated" USING ((("id" = "auth"."uid"()) OR ("lower"("email") = "lower"(("auth"."jwt"() ->> 'email'::"text")))));



CREATE POLICY "users read own notifications" ON "public"."user_notifications" FOR SELECT USING (("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("receiver_email", ''::"text"))));



CREATE POLICY "users update own notifications" ON "public"."user_notifications" FOR UPDATE USING (("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("receiver_email", ''::"text")))) WITH CHECK (("lower"(COALESCE(("auth"."jwt"() ->> 'email'::"text"), ''::"text")) = "lower"(COALESCE("receiver_email", ''::"text"))));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_create_shipping_qr"("p_request_id" "uuid", "p_order_number" "text", "p_carrier" "text", "p_tracking_number" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_create_shipping_qr"("p_request_id" "uuid", "p_order_number" "text", "p_carrier" "text", "p_tracking_number" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_create_shipping_qr"("p_request_id" "uuid", "p_order_number" "text", "p_carrier" "text", "p_tracking_number" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."artist_accept_request"("p_request_id" "uuid", "p_artist_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."artist_accept_request"("p_request_id" "uuid", "p_artist_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."artist_accept_request"("p_request_id" "uuid", "p_artist_amount" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."artist_accept_request"("p_request_id" "uuid", "p_order_number" "text", "p_artist_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."artist_accept_request"("p_request_id" "uuid", "p_order_number" "text", "p_artist_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."artist_accept_request"("p_request_id" "uuid", "p_order_number" "text", "p_artist_amount" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."artist_decline_request"("p_request_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."artist_decline_request"("p_request_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."artist_decline_request"("p_request_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."artist_mark_request_completed"("p_request_id" "uuid", "p_order_number" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."artist_mark_request_completed"("p_request_id" "uuid", "p_order_number" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."artist_mark_request_completed"("p_request_id" "uuid", "p_order_number" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."artist_mark_request_completed"("p_request_id" "uuid", "p_order_number" "text", "p_artist_photos" "jsonb", "p_shipping" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."artist_mark_request_completed"("p_request_id" "uuid", "p_order_number" "text", "p_artist_photos" "jsonb", "p_shipping" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."artist_mark_request_completed"("p_request_id" "uuid", "p_order_number" "text", "p_artist_photos" "jsonb", "p_shipping" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."client_request_before_save_defaults"() TO "anon";
GRANT ALL ON FUNCTION "public"."client_request_before_save_defaults"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."client_request_before_save_defaults"() TO "service_role";



GRANT ALL ON FUNCTION "public"."client_request_mirror_legacy_json"() TO "anon";
GRANT ALL ON FUNCTION "public"."client_request_mirror_legacy_json"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."client_request_mirror_legacy_json"() TO "service_role";



GRANT ALL ON TABLE "public"."company_custom_requests" TO "anon";
GRANT ALL ON TABLE "public"."company_custom_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."company_custom_requests" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_brand_requests_for_company_app"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_brand_requests_for_company_app"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_brand_requests_for_company_app"() TO "service_role";



GRANT ALL ON TABLE "public"."client_custom_requests" TO "anon";
GRANT ALL ON TABLE "public"."client_custom_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."client_custom_requests" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_client_requests_for_app"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_client_requests_for_app"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_client_requests_for_app"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_admin_client_registered"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_admin_client_registered"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_admin_client_registered"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_admin_client_request_created"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_admin_client_request_created"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_admin_client_request_created"() TO "service_role";



GRANT ALL ON FUNCTION "public"."save_artist_completion_photos"("p_request_id" "uuid", "p_order_number" "text", "p_photos" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."save_artist_completion_photos"("p_request_id" "uuid", "p_order_number" "text", "p_photos" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_artist_completion_photos"("p_request_id" "uuid", "p_order_number" "text", "p_photos" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_client_request_legacy_json"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_client_request_legacy_json"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_client_request_legacy_json"() TO "service_role";



GRANT ALL ON TABLE "public"."admin_notifications" TO "anon";
GRANT ALL ON TABLE "public"."admin_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."admin_users" TO "anon";
GRANT ALL ON TABLE "public"."admin_users" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_users" TO "service_role";



GRANT ALL ON TABLE "public"."artist" TO "anon";
GRANT ALL ON TABLE "public"."artist" TO "authenticated";
GRANT ALL ON TABLE "public"."artist" TO "service_role";



GRANT ALL ON TABLE "public"."artist_portfolio_items" TO "anon";
GRANT ALL ON TABLE "public"."artist_portfolio_items" TO "authenticated";
GRANT ALL ON TABLE "public"."artist_portfolio_items" TO "service_role";



GRANT ALL ON TABLE "public"."artists" TO "anon";
GRANT ALL ON TABLE "public"."artists" TO "authenticated";
GRANT ALL ON TABLE "public"."artists" TO "service_role";



GRANT ALL ON TABLE "public"."ascension_audit_logs" TO "anon";
GRANT ALL ON TABLE "public"."ascension_audit_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."ascension_audit_logs" TO "service_role";



GRANT ALL ON TABLE "public"."ascension_current" TO "anon";
GRANT ALL ON TABLE "public"."ascension_current" TO "authenticated";
GRANT ALL ON TABLE "public"."ascension_current" TO "service_role";



GRANT ALL ON TABLE "public"."ascension_overrides" TO "anon";
GRANT ALL ON TABLE "public"."ascension_overrides" TO "authenticated";
GRANT ALL ON TABLE "public"."ascension_overrides" TO "service_role";



GRANT ALL ON TABLE "public"."auth_email_aliases" TO "anon";
GRANT ALL ON TABLE "public"."auth_email_aliases" TO "authenticated";
GRANT ALL ON TABLE "public"."auth_email_aliases" TO "service_role";



GRANT ALL ON TABLE "public"."brand_notifications" TO "anon";
GRANT ALL ON TABLE "public"."brand_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."brand_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."chat_messages" TO "anon";
GRANT ALL ON TABLE "public"."chat_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_messages" TO "service_role";



GRANT ALL ON TABLE "public"."chat_rooms" TO "anon";
GRANT ALL ON TABLE "public"."chat_rooms" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_rooms" TO "service_role";



GRANT ALL ON TABLE "public"."client" TO "anon";
GRANT ALL ON TABLE "public"."client" TO "authenticated";
GRANT ALL ON TABLE "public"."client" TO "service_role";



GRANT ALL ON TABLE "public"."client_artist" TO "anon";
GRANT ALL ON TABLE "public"."client_artist" TO "authenticated";
GRANT ALL ON TABLE "public"."client_artist" TO "service_role";



GRANT ALL ON TABLE "public"."client_artist_portfolio_items" TO "anon";
GRANT ALL ON TABLE "public"."client_artist_portfolio_items" TO "authenticated";
GRANT ALL ON TABLE "public"."client_artist_portfolio_items" TO "service_role";



GRANT ALL ON TABLE "public"."client_artist_registration_drafts" TO "anon";
GRANT ALL ON TABLE "public"."client_artist_registration_drafts" TO "authenticated";
GRANT ALL ON TABLE "public"."client_artist_registration_drafts" TO "service_role";



GRANT ALL ON TABLE "public"."client_custom_requests_details" TO "anon";
GRANT ALL ON TABLE "public"."client_custom_requests_details" TO "authenticated";
GRANT ALL ON TABLE "public"."client_custom_requests_details" TO "service_role";



GRANT ALL ON TABLE "public"."clients" TO "anon";
GRANT ALL ON TABLE "public"."clients" TO "authenticated";
GRANT ALL ON TABLE "public"."clients" TO "service_role";



GRANT ALL ON TABLE "public"."company" TO "anon";
GRANT ALL ON TABLE "public"."company" TO "authenticated";
GRANT ALL ON TABLE "public"."company" TO "service_role";



GRANT ALL ON TABLE "public"."company_custom_requests_details" TO "anon";
GRANT ALL ON TABLE "public"."company_custom_requests_details" TO "authenticated";
GRANT ALL ON TABLE "public"."company_custom_requests_details" TO "service_role";



GRANT ALL ON TABLE "public"."mail_queue" TO "anon";
GRANT ALL ON TABLE "public"."mail_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."mail_queue" TO "service_role";



GRANT ALL ON TABLE "public"."portfolio_items" TO "anon";
GRANT ALL ON TABLE "public"."portfolio_items" TO "authenticated";
GRANT ALL ON TABLE "public"."portfolio_items" TO "service_role";



GRANT ALL ON TABLE "public"."request_chat_messages" TO "anon";
GRANT ALL ON TABLE "public"."request_chat_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."request_chat_messages" TO "service_role";



GRANT ALL ON TABLE "public"."request_chats" TO "anon";
GRANT ALL ON TABLE "public"."request_chats" TO "authenticated";
GRANT ALL ON TABLE "public"."request_chats" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."sms_outbox" TO "anon";
GRANT ALL ON TABLE "public"."sms_outbox" TO "authenticated";
GRANT ALL ON TABLE "public"."sms_outbox" TO "service_role";



GRANT ALL ON TABLE "public"."tip_payout_queue" TO "anon";
GRANT ALL ON TABLE "public"."tip_payout_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."tip_payout_queue" TO "service_role";



GRANT ALL ON TABLE "public"."tips" TO "anon";
GRANT ALL ON TABLE "public"."tips" TO "authenticated";
GRANT ALL ON TABLE "public"."tips" TO "service_role";



GRANT ALL ON TABLE "public"."user_notifications" TO "anon";
GRANT ALL ON TABLE "public"."user_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."user_notifications" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";








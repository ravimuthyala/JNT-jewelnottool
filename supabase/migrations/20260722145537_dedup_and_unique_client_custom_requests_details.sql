CREATE UNIQUE INDEX client_custom_requests_details_request_key_uniq
  ON public.client_custom_requests_details USING btree (request_id, detail_key);

-- A client submitting a review (review_artist_page.dart and
-- order_details_pages.dart's _DeliveredReviewPanel) needs to update the
-- *artist's* aggregate rating/review-count columns after rating them. Both
-- call sites did this with a direct `.update()` against the artist/
-- client_artist table from the client's own session -- which RLS silently
-- no-ops (an UPDATE whose WHERE clause matches zero rows after RLS
-- filtering is not an error to Postgrest, so the client-side code always
-- logged "succeeded" even though nothing was ever written). Confirmed live:
-- an artist's `rating`/`average_rating`/`review_count`/`stats` were all
-- still null after a review that the app reported as successfully applied.
--
-- This function runs as SECURITY DEFINER so it can perform that one
-- specific, narrow write regardless of the caller's session, without
-- granting clients any broader UPDATE access to other users' artist rows.
create or replace function public.apply_client_review_to_artist(
  p_table text,
  p_artist_id uuid,
  p_rating numeric,
  p_review_count integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_table not in ('artist', 'client_artist') then
    raise exception 'apply_client_review_to_artist: invalid table %', p_table;
  end if;

  if p_rating is null or p_rating < 0 or p_rating > 5 then
    raise exception 'apply_client_review_to_artist: invalid rating %', p_rating;
  end if;

  if p_table = 'artist' then
    update public.artist
    set
      rating = p_rating,
      average_rating = p_rating,
      review_count = p_review_count,
      reviews = p_review_count,
      panel_rating = p_rating,
      panel_reviews = p_review_count,
      updated_at = now()
    where id = p_artist_id;
  else
    update public.client_artist
    set
      rating = p_rating,
      average_rating = p_rating,
      review_count = p_review_count,
      reviews = p_review_count,
      panel_rating = p_rating,
      panel_reviews = p_review_count,
      updated_at = now()
    where id = p_artist_id;
  end if;
end;
$$;

-- Only signed-in clients submit reviews, so this never needs to be callable
-- anonymously.
grant execute on function public.apply_client_review_to_artist(text, uuid, numeric, integer) to authenticated;

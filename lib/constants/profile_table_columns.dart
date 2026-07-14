// Column projection lists for the `client`/`client_artist`/`artist`/`company`
// profile tables, verified against the live Supabase schema (2026-07) and
// cross-referenced against every field read by client-facing pages
// (client_campaigns_page, client_profile_page, client_home_page,
// client_home_artist_portfolio_page, client_artists_page,
// client_custom_request_page(_v2)/with_artist_page).
//
// Only applies to reads that never merge-and-write-back the same row (see
// docs/DB_OPTIMIZATION_PLAN.md client-side audit) — do not use these for
// read-modify-write flows without re-verifying the write path first.
const String kClientTableColumns =
    'address, ascension, basic, client, communication_preferences, email, id, '
    'measurements, nail_preferences, nfc_eligible, panel_artist_portfolio_images, '
    'panel_display_name, panel_email, panel_name, panel_phone, panel_portfolio_images, '
    'portfolio, portfolio_images, portfolio_items, profile, stats';

// Note: this schema has separate literal camelCase duplicate columns
// alongside their snake_case counterparts (e.g. `avatarUrl` AND `avatar_url`
// both exist), a legacy artifact of earlier data migrations. Several client
// pages (client_artists_page, client_home_page, client_home_artist_portfolio_page)
// read the camelCase versions as a fallback, so both must be listed here —
// verified column-by-column against every top-level fallback those pages read.
const String kClientArtistTableColumns =
    'address, artist, artist_profile, ascension, availability, avatarUrl, basic, bio, city, '
    'client, communication_preferences, country, credentials, direct_requests_enabled, '
    'displayName, email, fullName, id, measurements, nail_preferences, name, nfc_eligible, '
    'nfc_request_enabled, panel_artist_portfolio_images, panel_displayName, panel_display_name, '
    'panel_email, panel_nameOrStudio, panel_name, panel_phone, panel_portfolio_images, '
    'panel_profileImageUrl, photoUrl, portfolio, portfolio_images, portfolio_items, pricing, '
    'profile, profileImageUrl, profilePhotoUrl, rating, services, state, stats, studioName, uid';

const String kArtistTableColumns =
    'address, artist, ascension, availability, avatarUrl, avatar_url, basic, bio, city, client, '
    'country, credentials, currency, direct_requests_enabled, displayName, email, fullName, id, '
    'language_spoken, nail_preferences, name, nfc_request_enabled, '
    'panel_artist_portfolio_images, panel_bio, panel_city, panel_country, panel_currency, '
    'panel_direct_requests_enabled, panel_displayName, panel_display_name, panel_email, '
    'panel_language_spoken, panel_max_price, panel_min_price, panel_nail_tech_type, '
    'panel_name, panel_nameOrStudio, panel_phone, panel_portfolio_images, '
    'panel_practice_duration, panel_pro_years_experience, panel_profileImageUrl, '
    'panel_profile_image_url, panel_services, panel_state, panel_studio_name, panel_zip, '
    'photoUrl, photo_url, portfolio, portfolio_images, portfolio_items, pricing, profile, '
    'profileImageUrl, profilePhotoUrl, rating, services, state, stats, studioName, uid';

const String kCompanyTableColumns =
    'addresses, avatar_url, basic, data, email, id, panel_profile_image_url, photo_url, '
    'profile, profile_image_url, status';

/// Returns a verified column-projection list for known profile tables, or
/// `null` for anything else (e.g. the legacy `clients` singular/plural
/// variants) so callers can fall back to a bare `.select()` rather than risk
/// a PostgREST error from selecting nonexistent columns.
String? columnsForProfileTable(String table) {
  switch (table) {
    case 'client':
      return kClientTableColumns;
    case 'client_artist':
      return kClientArtistTableColumns;
    case 'artist':
      return kArtistTableColumns;
    case 'company':
      return kCompanyTableColumns;
    default:
      return null;
  }
}

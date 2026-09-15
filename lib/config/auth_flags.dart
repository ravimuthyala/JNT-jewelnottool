const bool kRequireEmailVerification = true;

/// TEST-ONLY: routes signup and password-reset around Supabase Auth's
/// built-in mailer (which is what hit the "email rate limit exceeded"
/// error during registration testing) via the admin-auth-simulate edge
/// function instead. No confirmation/reset email is sent at all in this
/// mode -- SupabaseAuthService.signup creates a pre-confirmed user directly,
/// and sendPasswordResetEmail returns the reset link directly instead of
/// emailing it. This is the auth-email counterpart to send-queued-emails'
/// simulation mode for order-shipped/delivered emails.
///
/// As of 2026-09-10, deliberately active in EVERY environment including
/// Production, at explicit request, because Production's real SMTP isn't
/// configured yet either -- SupabaseAuthService no longer gates this on
/// Environment.isProduction (see the comment there). That means Production
/// can currently create pre-confirmed users and generate password-reset
/// links via the Admin API without owning the inbox. Flip this to false
/// (and drop the admin-auth-simulate function's ADMIN_SIMULATE_SECRET on
/// every project it was set on) once real SMTP is verified working
/// end-to-end for auth emails -- it deliberately bypasses real
/// verification/reset emails and must not stay enabled once that's live.
const bool kSimulateAuthEmailSending = true;

/// Shared secret the admin-auth-simulate edge function requires on every
/// request (header `x-simulate-secret`) so an anon-key holder can't invoke
/// it uninvited -- the function also fails closed entirely if its own
/// ADMIN_SIMULATE_SECRET env var isn't set on the project, so this string
/// alone isn't the only gate. Must match that env var exactly on every
/// project the function is deployed to (currently both UAT and
/// Production -- see kSimulateAuthEmailSending's note above on why).
const String kAuthSimulateSharedSecret = 'jnt-uat-auth-simulate-2026';

/// TEST-ONLY escape hatch: shows a "Simulate email confirmation" button on
/// the post-registration verification modal so QA can continue past it
/// without a working email/SMTP integration. It calls the
/// `simulate_confirm_current_user_email` Postgres RPC (see
/// supabase/migrations), which marks the *signed-in* user's own email as
/// confirmed -- it never touches anyone else's account.
///
/// Flip this to false (or delete the RPC) once real confirmation emails are
/// verified working end-to-end -- it deliberately bypasses verification and
/// must not ship enabled to production users.
const bool kEnableEmailVerificationTestSimulation = true;


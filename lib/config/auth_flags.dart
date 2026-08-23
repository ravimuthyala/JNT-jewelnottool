const bool kRequireEmailVerification = true;

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


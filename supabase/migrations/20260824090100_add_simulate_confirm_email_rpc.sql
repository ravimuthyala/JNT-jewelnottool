-- TEST-ONLY: lets the signed-in user mark their own email as confirmed
-- without a working SMTP/email integration, so the Option 2 (auto sign-in
-- after confirmation) flow can be exercised in EmailVerificationPendingPage
-- via the "Simulate email confirmation" button
-- (kEnableEmailVerificationTestSimulation in lib/config/auth_flags.dart).
--
-- SECURITY DEFINER is required because auth.users isn't writable by the
-- authenticated role directly. The WHERE id = auth.uid() clause scopes this
-- to the caller's own row only -- it can never confirm anyone else's email.
--
-- Drop this function (and flip kEnableEmailVerificationTestSimulation to
-- false) once real confirmation emails are verified working end-to-end --
-- it deliberately bypasses email verification and must not remain reachable
-- once the real flow is live for production users.
create or replace function public.simulate_confirm_current_user_email()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'simulate_confirm_current_user_email: no authenticated user';
  end if;

  -- confirmed_at is a generated column (derived from email_confirmed_at /
  -- phone_confirmed_at) on current Supabase auth schemas, so it isn't set
  -- directly here -- email_confirmed_at alone is what the app checks
  -- (see User.emailConfirmedAt in email_verification_pending_page.dart).
  update auth.users
  set email_confirmed_at = coalesce(email_confirmed_at, now())
  where id = auth.uid();
end;
$$;

grant execute on function public.simulate_confirm_current_user_email() to authenticated;

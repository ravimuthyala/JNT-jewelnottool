// TEST-ONLY: bypasses Supabase Auth's built-in mailer (GoTrue) for signup
// confirmation and password reset, using the Auth Admin API, so QA can
// exercise those flows without hitting the built-in mailer's rate limit and
// without a real inbox. This is the auth-side counterpart to
// send-queued-emails' simulation mode for order-shipped/delivered emails --
// see lib/config/auth_flags.dart (kSimulateAuthEmailSending) for the client
// switch and lib/services/supabase_auth_service.dart for how it's called.
//
// SECURITY: this function can create arbitrary confirmed users and
// generate a password-reset link for ANY email -- the latter is equivalent
// to a password-reset token, so treat it like a credential. It fails
// closed by default: every request must present a shared secret matching
// the ADMIN_SIMULATE_SECRET env var, and if that env var isn't set at all,
// every request is rejected regardless of what's presented. Never enable
// this in Production -- SupabaseAuthService additionally hard-blocks calling
// it outside dev/UAT (see Environment.isProduction there), so this is
// defense in depth, not the only gate.
//
// Deploy: supabase functions deploy admin-auth-simulate --project-ref <ref>
// Secrets (UAT/dev only -- never set in Production):
//   supabase secrets set ADMIN_SIMULATE_SECRET=<random-string> --project-ref <ref>
// That same string must be copied into kAuthSimulateSharedSecret in
// lib/config/auth_flags.dart so the app's requests are accepted.
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-injected by the platform.
//
// Drop this function (and flip kSimulateAuthEmailSending to false) once
// real SMTP is verified working end-to-end for auth emails -- matches the
// same lifecycle note on simulate_confirm_current_user_email.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ADMIN_SIMULATE_SECRET = Deno.env.get('ADMIN_SIMULATE_SECRET');

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

interface RequestBody {
  action: 'create_confirmed_user' | 'generate_reset_link';
  email?: string;
  password?: string;
  redirectTo?: string;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (!ADMIN_SIMULATE_SECRET) {
    // Fails closed -- this function is inert until someone deliberately
    // opts in by setting the secret, so deploying it doesn't itself
    // introduce any risk.
    return jsonResponse({ error: 'simulation not enabled on this project' }, 403);
  }

  if (req.headers.get('x-simulate-secret') !== ADMIN_SIMULATE_SECRET) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'invalid JSON body' }, 400);
  }

  const email = (body.email ?? '').trim().toLowerCase();
  if (!email || !email.includes('@')) {
    return jsonResponse({ error: 'valid email is required' }, 400);
  }

  if (body.action === 'create_confirmed_user') {
    const password = body.password ?? '';
    if (!password) {
      return jsonResponse({ error: 'password is required' }, 400);
    }

    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // pre-confirmed -- no confirmation email is sent
    });

    if (error) {
      return jsonResponse({ error: error.message }, 400);
    }

    return jsonResponse({ userId: data.user?.id ?? null });
  }

  if (body.action === 'generate_reset_link') {
    const { data, error } = await supabase.auth.admin.generateLink({
      type: 'recovery',
      email,
      options: body.redirectTo ? { redirectTo: body.redirectTo } : undefined,
    });

    if (error) {
      return jsonResponse({ error: error.message }, 400);
    }

    // action_link is the full recovery URL a real email would have
    // contained -- returning it directly means no email is sent at all.
    return jsonResponse({ actionLink: data.properties?.action_link ?? null });
  }

  return jsonResponse({ error: `unknown action: ${body.action}` }, 400);
});

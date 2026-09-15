// Drains public.mail_queue by sending each 'queued' row through Resend's
// API, then marks it 'sent' or 'failed'. This is the missing piece behind
// order-shipped/order-delivered "emails" that were being queued and
// silently abandoned -- see the mail_queue table comment history
// (20260824090000_add_queue_client_email_rpc.sql) for how that was found.
//
// Invoked on a schedule by pg_cron -- see
// supabase/migrations/20260909120100_schedule_mail_queue_worker.sql for the
// schedule and the one-time Vault secret setup it depends on.
//
// SIMULATION MODE: real Resend sending isn't wired up yet (no domain/API
// key finalized as of this writing), so this run in SIMULATED mode --
// mirrors the existing kEnableEmailVerificationTestSimulation /
// simulate_confirm_current_user_email pattern used for auth email testing
// (lib/config/auth_flags.dart, 20260824090100_add_simulate_confirm_email_rpc.sql).
// A row is picked as simulated automatically whenever RESEND_API_KEY isn't
// set (SIMULATE below), OR whenever MAIL_SIMULATION_MODE=true is set
// explicitly -- the latter lets you force simulation even after a real key
// is configured, for controlled QA. In simulated mode, the REAL Resend
// send block below still exists and is fully wired -- it's just skipped in
// favor of marking the row 'simulated' and logging what would have been
// sent (recipients + subject), so the whole queue -> cron -> processed
// pipeline can be exercised end-to-end without spending a real send or
// needing a verified domain yet.
//
// Deploy: supabase functions deploy send-queued-emails --project-ref <ref>
// Secrets (once Resend is ready, to go live):
//   supabase secrets set RESEND_API_KEY=re_... --project-ref <ref>
//   supabase secrets set MAIL_FROM_EMAIL=no-reply@jntnails.com --project-ref <ref>
//   supabase secrets set MAIL_FROM_NAME="JNT" --project-ref <ref>
// To force simulation even with a real key set:
//   supabase secrets set MAIL_SIMULATION_MODE=true --project-ref <ref>
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-injected by the platform.
//
// This function is deployed with the default verify_jwt = true, so the
// platform itself rejects any caller without a valid Supabase JWT --
// pg_cron supplies the project's service role key (pulled from Vault, never
// committed to a migration file) as that JWT. No separate custom secret is
// needed on top of that.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const MAIL_FROM_EMAIL = Deno.env.get('MAIL_FROM_EMAIL') ?? 'no-reply@jntnails.com';
const MAIL_FROM_NAME = Deno.env.get('MAIL_FROM_NAME') ?? 'JNT';
const FORCE_SIMULATION = (Deno.env.get('MAIL_SIMULATION_MODE') ?? '').toLowerCase() === 'true';

// No real key yet -> always simulate. A real key can still be forced into
// simulation via MAIL_SIMULATION_MODE=true for controlled testing later.
const SIMULATE = FORCE_SIMULATION || !RESEND_API_KEY;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// Keeps each invocation fast and bounded -- pg_cron runs this every couple
// of minutes, so a deep backlog drains over a few ticks rather than one
// invocation risking the edge function's execution time limit.
const BATCH_SIZE = 25;

interface MailQueueRow {
  id: string;
  to_email: string | null;
  to_list: string[] | null;
  subject: string | null;
  text: string | null;
  html: string | null;
}

async function markRow(
  id: string,
  status: 'sent' | 'simulated' | 'failed',
  lastError: string | null,
) {
  await supabase
    .from('mail_queue')
    .update({
      status,
      processed_at: new Date().toISOString(),
      last_error: lastError,
    })
    .eq('id', id);
}

Deno.serve(async (_req: Request) => {
  const { data: rows, error } = await supabase
    .from('mail_queue')
    .select('id, to_email, to_list, subject, text, html')
    .eq('status', 'queued')
    .order('created_at', { ascending: true })
    .limit(BATCH_SIZE);

  if (error) {
    console.error('send-queued-emails: failed to read mail_queue', error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let sent = 0;
  let simulated = 0;
  let failed = 0;
  const simulatedPreview: Array<{ to: string[]; subject: string }> = [];

  for (const row of (rows ?? []) as MailQueueRow[]) {
    const recipients = row.to_list?.length
      ? row.to_list
      : row.to_email
        ? [row.to_email]
        : [];

    if (!recipients.length || !row.subject) {
      await markRow(row.id, 'failed', 'missing recipient or subject');
      failed++;
      continue;
    }

    if (SIMULATE) {
      // Test-only path -- does NOT call Resend. Marks the row 'simulated'
      // (distinct from a real 'sent') and logs what would have gone out,
      // so the queue -> cron -> processed pipeline is fully exercisable
      // before a real domain/API key exists. Flip RESEND_API_KEY on (and
      // leave MAIL_SIMULATION_MODE unset) to switch this row to the real
      // send path below with no other code changes.
      console.log(
        `send-queued-emails: SIMULATED send to [${recipients.join(', ')}]: "${row.subject}"`,
      );
      await markRow(row.id, 'simulated', null);
      simulated++;
      simulatedPreview.push({ to: recipients, subject: row.subject });
      continue;
    }

    try {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: `${MAIL_FROM_NAME} <${MAIL_FROM_EMAIL}>`,
          to: recipients,
          subject: row.subject,
          html: row.html ?? undefined,
          text: row.text ?? undefined,
        }),
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(`Resend ${res.status}: ${body}`);
      }

      await markRow(row.id, 'sent', null);
      sent++;
    } catch (e) {
      console.error(`send-queued-emails: failed to send row ${row.id}`, e);
      await markRow(row.id, 'failed', String(e));
      failed++;
    }
  }

  return new Response(
    JSON.stringify({
      simulationMode: SIMULATE,
      processed: (rows ?? []).length,
      sent,
      simulated,
      failed,
      simulatedPreview: SIMULATE ? simulatedPreview : undefined,
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
});

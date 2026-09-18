// Drains public.sms_outbox by sending each 'queued' row through Twilio's
// Messages API, then marks it 'sent' or 'failed'. Mirrors
// send-queued-emails/index.ts (same queue -> cron -> worker shape, same
// SIMULATE-when-no-credentials fallback) -- see that function's own header
// comment for the pattern this follows. Before this, sms_outbox had rows
// written by NotificationsService.queueSms() but nothing ever consumed them
// (see the 20260917 reminder-SMS work that surfaced the gap).
//
// Invoked on a schedule by pg_cron -- see
// supabase/migrations/20260917120000_schedule_sms_queue_worker.sql for the
// schedule and the one-time Vault secret setup it depends on.
//
// SIMULATION MODE: real Twilio sending isn't wired up yet (no account
// created/verified as of this writing), so this runs in SIMULATED mode
// until TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN/TWILIO_FROM_NUMBER are all set.
// A row is picked as simulated automatically whenever any of those three is
// missing (SIMULATE below), OR whenever SMS_SIMULATION_MODE=true is set
// explicitly -- the latter lets you force simulation even after real
// credentials are configured, for controlled QA. In simulated mode, the
// REAL Twilio send block below still exists and is fully wired -- it's just
// skipped in favor of marking the row 'simulated' and logging what would
// have been sent (to number + message), so the whole queue -> cron ->
// processed pipeline can be exercised end-to-end before a real Twilio
// account exists.
//
// Deploy: supabase functions deploy send-queued-sms --project-ref <ref>
// Secrets (once Twilio is ready, to go live):
//   supabase secrets set TWILIO_ACCOUNT_SID=AC... --project-ref <ref>
//   supabase secrets set TWILIO_AUTH_TOKEN=... --project-ref <ref>
//   supabase secrets set TWILIO_FROM_NUMBER=+1... --project-ref <ref>
// To force simulation even with real credentials set:
//   supabase secrets set SMS_SIMULATION_MODE=true --project-ref <ref>
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
const TWILIO_ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID');
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN');
const TWILIO_FROM_NUMBER = Deno.env.get('TWILIO_FROM_NUMBER');
const FORCE_SIMULATION = (Deno.env.get('SMS_SIMULATION_MODE') ?? '').toLowerCase() === 'true';

// Any credential missing -> always simulate. Real credentials can still be
// forced into simulation via SMS_SIMULATION_MODE=true for controlled testing.
const SIMULATE =
  FORCE_SIMULATION || !TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_FROM_NUMBER;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// Keeps each invocation fast and bounded -- pg_cron runs this every couple
// of minutes, so a deep backlog drains over a few ticks rather than one
// invocation risking the edge function's execution time limit.
const BATCH_SIZE = 25;

interface SmsOutboxRow {
  id: string;
  to_number: string | null;
  message: string | null;
}

// panel_phone (see the artist/client/client_artist tables) is stored as
// just areaCode+localNumber digits with no country code or '+' -- raw
// output of RegistrationInputUtils.normalizePhone/normalizeAreaCode in the
// Flutter app, not E.164. Twilio requires E.164. This assumes US/Canada
// numbers (the app's only timezone default is America/New_York and there's
// no country picker in registration) -- revisit if that ever changes.
function toE164(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.startsWith('+')) return trimmed;
  const digits = trimmed.replace(/[^0-9]/g, '');
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith('1')) return `+${digits}`;
  return null; // not a recognizable US/CA number -- fail closed rather than guess
}

async function markRow(id: string, status: 'sent' | 'simulated' | 'failed', lastError: string | null) {
  await supabase
    .from('sms_outbox')
    .update({
      status,
      processed_at: new Date().toISOString(),
      payload: lastError ? { lastError } : {},
    })
    .eq('id', id);
}

Deno.serve(async (_req: Request) => {
  const { data: rows, error } = await supabase
    .from('sms_outbox')
    .select('id, to_number, message')
    .eq('status', 'queued')
    .order('created_at', { ascending: true })
    .limit(BATCH_SIZE);

  if (error) {
    console.error('send-queued-sms: failed to read sms_outbox', error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let sent = 0;
  let simulated = 0;
  let failed = 0;
  const simulatedPreview: Array<{ to: string; message: string }> = [];

  for (const row of (rows ?? []) as SmsOutboxRow[]) {
    const message = (row.message ?? '').trim();
    const to = row.to_number ? toE164(row.to_number) : null;

    if (!to || !message) {
      await markRow(row.id, 'failed', !to ? 'missing/unrecognized phone number' : 'missing message');
      failed++;
      continue;
    }

    if (SIMULATE) {
      // Test-only path -- does NOT call Twilio. Marks the row 'simulated'
      // (distinct from a real 'sent') and logs what would have gone out, so
      // the queue -> cron -> processed pipeline is fully exercisable before
      // a real Twilio account exists. Set the three TWILIO_* secrets (and
      // leave SMS_SIMULATION_MODE unset) to switch to the real send path
      // below with no other code changes.
      console.log(`send-queued-sms: SIMULATED send to ${to}: "${message}"`);
      await markRow(row.id, 'simulated', null);
      simulated++;
      simulatedPreview.push({ to, message });
      continue;
    }

    try {
      const res = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`,
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`)}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: new URLSearchParams({
            To: to,
            From: TWILIO_FROM_NUMBER!,
            Body: message,
          }),
        },
      );

      if (!res.ok) {
        const body = await res.text();
        throw new Error(`Twilio ${res.status}: ${body}`);
      }

      await markRow(row.id, 'sent', null);
      sent++;
    } catch (e) {
      console.error(`send-queued-sms: failed to send row ${row.id}`, e);
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

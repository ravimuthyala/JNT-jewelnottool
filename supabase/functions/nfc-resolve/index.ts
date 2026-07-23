// NFC chip resolver -- the public endpoint a tapped chip's stable URL points
// to (https://www.jntnails.com/n/{chipId} is routed here at the DNS layer).
//
// Chips no longer carry their destination directly. Instead they carry
// https://<supabase-project>.functions.supabase.co/nfc-resolve/{chipId}
// (fronted by www.jntnails.com/n/{chipId}), and this function looks up what
// that chip currently points to at request time -- so changing what's active,
// editing the underlying value, or deactivating a lost/damaged chip all take
// effect immediately with no need to rewrite the physical chip.
//
// Deploy: supabase functions deploy nfc-resolve --project-ref <ref>
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-injected by the platform.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

interface NfcChipRow {
  id: string;
  owner_id: string;
  owner_table: 'client' | 'client_artist';
  label: string | null;
  status: string;
  active_item_key: string | null;
}

function htmlPage(title: string, message: string): Response {
  const body = `<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${title}</title>
<style>
  body { font-family: -apple-system, Helvetica, Arial, sans-serif; background: #faf7f5;
         color: #1a1a1a; display: flex; align-items: center; justify-content: center;
         min-height: 100vh; margin: 0; padding: 24px; text-align: center; }
  .card { max-width: 420px; }
  h1 { font-size: 20px; margin-bottom: 8px; }
  p { font-size: 15px; color: #444; white-space: pre-wrap; }
</style>
</head>
<body>
  <div class="card">
    <h1>${title}</h1>
    <p>${message}</p>
  </div>
</body>
</html>`;
  return new Response(body, {
    status: 200,
    headers: { 'content-type': 'text/html; charset=utf-8' },
  });
}

function stripAt(value: string): string {
  let clean = value.trim();
  while (clean.startsWith('@')) clean = clean.substring(1);
  return encodeURIComponent(clean);
}

function hasScheme(value: string): boolean {
  try {
    const u = new URL(value);
    return Boolean(u.protocol);
  } catch {
    return false;
  }
}

function urlOrFallback(value: string, fallback: string): string {
  return hasScheme(value) ? value : fallback;
}

function socialUrl(base: string, value: string): string {
  return urlOrFallback(value, `${base}${stripAt(value)}`);
}

function ensureUrl(value: string): string {
  if (hasScheme(value)) return value;
  if (value.includes('.') && !value.includes(' ')) return `https://${value}`;
  return value;
}

// Mirrors _buildNfcPayload in lib/pages/nfc_smart_nail_profile_page.dart --
// keep these in sync if new saved-item keys are added there.
function buildDestination(key: string, rawValue: string): string {
  const normalized = rawValue.replace(/\n/g, ' ').trim();
  switch (key) {
    case 'instagram':
      return socialUrl('https://instagram.com/', normalized);
    case 'tiktok':
      return socialUrl('https://www.tiktok.com/@', normalized);
    case 'snapchat':
      return socialUrl('https://www.snapchat.com/add/', normalized);
    case 'facebook':
      return urlOrFallback(normalized, `https://www.facebook.com/${normalized}`);
    case 'linkedin':
      return urlOrFallback(normalized, `https://www.linkedin.com/in/${normalized}`);
    case 'youtube':
      return urlOrFallback(normalized, `https://www.youtube.com/@${normalized}`);
    case 'pinterest':
      return urlOrFallback(normalized, `https://www.pinterest.com/${normalized}`);
    case 'xTwitter':
      return socialUrl('https://x.com/', normalized);
    case 'threads':
      return socialUrl('https://www.threads.net/@', normalized);
    case 'website':
    case 'website2':
    case 'website3':
    case 'spotify':
    case 'appleMusic':
    case 'amazonMusic':
    case 'soundCloud':
    case 'paypal':
      return ensureUrl(normalized);
    case 'contactCard':
      return `Contact Card\n${rawValue.trim()}`;
    case 'emergencyContact':
      return `Emergency Contact\n${rawValue.trim()}`;
    default:
      return normalized;
  }
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const segments = url.pathname.split('/').filter(Boolean);
  const chipId = segments[segments.length - 1] ?? '';

  if (!chipId) {
    return htmlPage('Not found', 'This link is missing a chip id.');
  }

  const { data: chip, error } = await supabase
    .from('nfc_chips')
    .select('id, owner_id, owner_table, label, status, active_item_key')
    .eq('id', chipId)
    .maybeSingle<NfcChipRow>();

  if (error || !chip) {
    return htmlPage('Not found', 'This NFC chip is not registered.');
  }

  if (chip.status !== 'active') {
    return htmlPage(
      'Chip deactivated',
      'This NFC chip has been reported lost or damaged and is no longer active.',
    );
  }

  if (!chip.active_item_key) {
    return htmlPage(
      'Not set up yet',
      "This chip's owner hasn't chosen what to share yet.",
    );
  }

  const { data: owner } = await supabase
    .from(chip.owner_table)
    .select('nfc_smart_nail_profile')
    .eq('id', chip.owner_id)
    .maybeSingle<{ nfc_smart_nail_profile: Record<string, unknown> | null }>();

  const profile = owner?.nfc_smart_nail_profile ?? {};
  const rawValue = String(profile[chip.active_item_key] ?? '').trim();

  if (!rawValue) {
    return htmlPage(
      'Not set up yet',
      "This chip's owner hasn't chosen what to share yet.",
    );
  }

  const destination = buildDestination(chip.active_item_key, rawValue);

  if (hasScheme(destination)) {
    return new Response(null, {
      status: 302,
      headers: { location: destination },
    });
  }

  return htmlPage('Contact info', destination);
});

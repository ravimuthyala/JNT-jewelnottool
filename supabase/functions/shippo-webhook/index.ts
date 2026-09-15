// Receives Shippo's track_updated events and is the ONLY place allowed to
// move a request's status forward automatically (shipped, in transit,
// delivered) once real labels are live. Today, "Mark as Shipped" (with a
// manually-picked Shipped Date) and "Mark as Delivered" are both artist/
// admin actions -- or, for testing, the simulated buttons in
// lib/pages/artist_completed_request_sheet.dart -- and both must stop being
// the primary path once this webhook is live, since the client's intended
// flow is Shippo driving shipped/delivered automatically from the carrier's
// own tracking scans, not the artist confirming a date by hand.
//
// STATUS: not active yet. Companion to create-shipping-label -- see that
// function's header for the activation steps.
//
// Unlike Stripe, Shippo does not HMAC-sign its webhook payloads, so this
// endpoint authenticates the same way ai-chat-assistant does: a shared
// secret compared against a header. Add the matching
// `[functions.shippo-webhook]` / `verify_jwt = false` block to
// supabase/config.toml when deploying (see ai-chat-assistant's entry there
// for the pattern), and register this function's URL + a `?secret=...`
// (or header, depending on what Shippo's webhook config supports) in the
// Shippo dashboard.
//
// Deploy: supabase functions deploy shippo-webhook --project-ref <ref>
// Secrets: supabase secrets set SHIPPO_WEBHOOK_SECRET=<random-string> --project-ref <ref>

// import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
//
// const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
// const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// const WEBHOOK_SECRET = Deno.env.get('SHIPPO_WEBHOOK_SECRET') ?? '';
//
// const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
//   auth: { persistSession: false },
// });
//
// // Shippo tracking_status.status values -> our shipping_status column.
// const STATUS_MAP: Record<string, string> = {
//   UNKNOWN: 'label_ready',
//   PRE_TRANSIT: 'label_ready',
//   TRANSIT: 'in_transit',
//   DELIVERED: 'delivered',
//   RETURNED: 'returned',
//   FAILURE: 'failed',
// };
//
// // Top-level `status` values that mean "already shipped or further along" --
// // a late/duplicate TRANSIT event after delivery must not roll status back.
// const ALREADY_SHIPPED_OR_LATER = new Set(['shipped', 'delivered']);
//
// Deno.serve(async (req) => {
//   if (req.method !== 'POST') {
//     return new Response('Method not allowed', { status: 405 });
//   }
//
//   const url = new URL(req.url);
//   const provided = req.headers.get('x-webhook-secret') ?? url.searchParams.get('secret') ?? '';
//   if (WEBHOOK_SECRET && provided !== WEBHOOK_SECRET) {
//     return new Response('Unauthorized', { status: 401 });
//   }
//
//   try {
//     const event = await req.json();
//     if (event.event !== 'track_updated') {
//       return new Response(JSON.stringify({ received: true, ignored: true }), {
//         headers: { 'Content-Type': 'application/json' },
//       });
//     }
//
//     const trackingNumber: string | undefined = event.data?.tracking_number;
//     const shippoStatus: string = event.data?.tracking_status?.status ?? 'UNKNOWN';
//     const statusDateRaw: string | undefined = event.data?.tracking_status?.status_date;
//     const etaRaw: string | undefined = event.data?.eta;
//     if (!trackingNumber) {
//       return new Response(JSON.stringify({ received: true }), {
//         headers: { 'Content-Type': 'application/json' },
//       });
//     }
//
//     const mappedStatus = STATUS_MAP[shippoStatus] ?? 'in_transit';
//     const nowIso = new Date().toISOString();
//     // Prefer the carrier's own scan timestamp for shippedAt/deliveredAt
//     // when Shippo provides one, falling back to "now" if it doesn't.
//     const eventIso = statusDateRaw ? new Date(statusDateRaw).toISOString() : nowIso;
//
//     for (const table of ['client_custom_requests', 'company_custom_requests']) {
//       const { data: row } = await supabase
//         .from(table)
//         .select('id, status, data, payload, details, shipping_label_carrier')
//         .eq('shipping_label_tracking_number', trackingNumber)
//         .maybeSingle();
//       if (!row) continue;
//
//       const currentStatus = (row.status ?? '').toString().toLowerCase();
//       const carrier = row.shipping_label_carrier ?? '';
//       const jsonCol = table === 'company_custom_requests' ? 'payload' : 'data';
//       const currentJson = (row as Record<string, unknown>)[jsonCol] as Record<string, unknown> ?? {};
//
//       const patch: Record<string, unknown> = {
//         shipping_status: mappedStatus,
//         updated_at: nowIso,
//       };
//       if (etaRaw) patch.estimated_delivery_at = etaRaw;
//
//       if (mappedStatus === 'in_transit' && !ALREADY_SHIPPED_OR_LATER.has(currentStatus)) {
//         // First real carrier scan after label purchase -- this is the
//         // actual "Shipped Date", replacing the artist's manual date
//         // picker + "Mark as Shipped" tap for labels Shippo generated.
//         patch.status = 'shipped';
//         patch.client_status = 'shipped';
//         patch.artist_status = 'shipped';
//         if (table === 'company_custom_requests') patch.brand_status = 'shipped';
//         patch.shipped_at = eventIso;
//         patch.shipped_by_courier = carrier;
//         patch.tracking_number = trackingNumber;
//         patch[jsonCol] = {
//           ...currentJson,
//           status: 'shipped',
//           clientStatus: 'shipped',
//           artistStatus: 'shipped',
//           ...(table === 'company_custom_requests' ? { brandStatus: 'shipped' } : {}),
//           shippedAt: eventIso,
//           shippedByCourier: carrier,
//           trackingNumber: trackingNumber,
//         };
//       } else if (mappedStatus === 'delivered') {
//         // Mirror _persistDeliveredRootStatus in
//         // artist_requests_page_redesign.dart so a webhook-driven delivery
//         // lands identically to today's manual "Mark as Delivered" action.
//         patch.status = 'delivered';
//         patch.client_status = 'delivered';
//         patch.artist_status = 'delivered';
//         if (table === 'company_custom_requests') patch.brand_status = 'delivered';
//         patch.delivered_at = eventIso;
//         patch.order_delivered_at = eventIso;
//         patch[jsonCol] = {
//           ...currentJson,
//           status: 'delivered',
//           clientStatus: 'delivered',
//           artistStatus: 'delivered',
//           ...(table === 'company_custom_requests' ? { brandStatus: 'delivered' } : {}),
//           deliveredAt: eventIso,
//           orderDeliveredAt: eventIso,
//         };
//       }
//
//       await supabase.from(table).update(patch).eq('id', row.id);
//       break;
//     }
//
//     return new Response(JSON.stringify({ received: true }), {
//       headers: { 'Content-Type': 'application/json' },
//     });
//   } catch (e) {
//     return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
//   }
// });

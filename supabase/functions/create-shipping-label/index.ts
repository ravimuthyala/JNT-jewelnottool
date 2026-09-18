// Purchases a Shippo shipping label for an artist's completed order and
// writes the resulting label/tracking data back onto the request row.
//
// STATUS: not active yet. lib/pages/artist_completed_request_sheet.dart's
// "Get Shipping Label" button only simulates label generation while
// kShippingLiveEnabled = false there. This function is scaffolding for when
// Shippo is actually wired up -- deploy it, set SHIPPO_API_TOKEN, and flip
// kShippingLiveEnabled to true.
//
// This function must own label purchase because it needs the Shippo
// *private* API token, which must never ship inside the Flutter app. The
// client only ever sees the returned label/tracking fields after they've
// been written back to the row.
//
// Deploy: supabase functions deploy create-shipping-label --project-ref <ref>
// Secrets: supabase secrets set SHIPPO_API_TOKEN=shippo_live_... --project-ref <ref>
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-injected by the platform.

// import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
//
// const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
// const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// const SHIPPO_API_TOKEN = Deno.env.get('SHIPPO_API_TOKEN')!;
//
// const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
//   auth: { persistSession: false },
// });
//
// interface RequestBody {
//   requestId: string;
//   sourceCollection: string; // 'Client_Custom_Requests' | 'Company_Custom_Requests'
//   carrier?: string; // 'USPS' | 'UPS' | 'FedEx' | 'DHL' -- artist's choice from
//                      // the Courier dropdown in artist_completed_request_sheet.dart;
//                      // falls back to the cheapest available rate if omitted/unmatched.
//   recipientKey?: string; // group orders shipping to each member individually
// }
//
// interface ShippoAddress {
//   name: string;
//   street1: string;
//   street2?: string;
//   city: string;
//   state: string;
//   zip: string;
//   country: string;
// }
//
// Deno.serve(async (req) => {
//   try {
//     const { requestId, sourceCollection, carrier }: RequestBody = await req.json();
//     if (!requestId) {
//       return new Response(JSON.stringify({ error: 'requestId is required' }), {
//         status: 400,
//       });
//     }
//
//     const table = sourceCollection === 'Company_Custom_Requests'
//       ? 'company_custom_requests'
//       : 'client_custom_requests';
//
//     const { data: row, error } = await supabase
//       .from(table)
//       .select('*')
//       .eq('id', requestId)
//       .maybeSingle();
//     if (error || !row) {
//       return new Response(JSON.stringify({ error: 'Request not found' }), {
//         status: 404,
//       });
//     }
//     if (row.shipping_label_ready) {
//       return new Response(JSON.stringify({ error: 'Label already generated' }), {
//         status: 409,
//       });
//     }
//
//     // Ship-from: the accepting artist's address, stored as flat
//     // panel_shipping_* columns on the `artist` table (see
//     // artist_registration_flow.dart's save payload).
//     const { data: artist, error: artistError } = await supabase
//       .from('artist')
//       .select(
//         'name, panel_shipping_address_line1, panel_shipping_address_line2, ' +
//         'panel_shipping_city, panel_shipping_state, panel_shipping_zip, ' +
//         'panel_shipping_country',
//       )
//       .eq('id', row.accepted_by_artist_id ?? row.artist_id)
//       .maybeSingle();
//     if (artistError || !artist) {
//       return new Response(JSON.stringify({ error: 'Artist address not found' }), {
//         status: 404,
//       });
//     }
//     const addressFrom: ShippoAddress = {
//       name: artist.name ?? 'JNT Artist',
//       street1: artist.panel_shipping_address_line1 ?? '',
//       street2: artist.panel_shipping_address_line2 ?? undefined,
//       city: artist.panel_shipping_city ?? '',
//       state: artist.panel_shipping_state ?? '',
//       zip: artist.panel_shipping_zip ?? '',
//       country: artist.panel_shipping_country ?? 'US',
//     };
//
//     // Ship-to: the recipient's address. Request rows/detail payloads use
//     // several historical key spellings for this -- mirror the same
//     // cascade lib/services/artist_requests_repository.dart already
//     // normalizes (shippingStreet / shippingAddressStreet /
//     // shipping_address_street / nested profileAddress.street, etc.)
//     // rather than assuming one fixed column layout.
//     const addressTo: ShippoAddress = {
//       name: row.client_name ?? row.contact_name ?? 'JNT Client',
//       street1: row.shipping_street ?? row.shipping_address_street ?? '',
//       city: row.shipping_city ?? '',
//       state: row.shipping_state ?? '',
//       zip: row.shipping_zip ?? '',
//       country: row.shipping_country ?? 'US',
//     };
//
//     const shipmentRes = await fetch('https://api.goshippo.com/shipments/', {
//       method: 'POST',
//       headers: {
//         Authorization: `ShippoToken ${SHIPPO_API_TOKEN}`,
//         'Content-Type': 'application/json',
//       },
//       body: JSON.stringify({
//         address_from: addressFrom,
//         address_to: addressTo,
//         parcels: [
//           {
//             length: '9',
//             width: '6',
//             height: '2',
//             distance_unit: 'in',
//             weight: '1',
//             mass_unit: 'lb',
//           },
//         ],
//         async: false,
//       }),
//     });
//     const shipment = await shipmentRes.json();
//     const rates: Array<{ provider: string }> = shipment.rates ?? [];
//     // Prefer a rate from the artist-selected carrier (Shippo's `provider`
//     // is a prefix match, e.g. 'USPS' matches 'USPS Priority Mail', 'DHL'
//     // matches 'DHL Express'); fall back to the cheapest available rate if
//     // no carrier was given or none of its rates came back for this route.
//     const rate = (carrier
//       ? rates.find((r) => r.provider?.toUpperCase().startsWith(carrier.toUpperCase()))
//       : undefined) ?? rates[0];
//     if (!rate) {
//       return new Response(JSON.stringify({ error: 'No shipping rate available' }), {
//         status: 502,
//       });
//     }
//
//     const transactionRes = await fetch('https://api.goshippo.com/transactions/', {
//       method: 'POST',
//       headers: {
//         Authorization: `ShippoToken ${SHIPPO_API_TOKEN}`,
//         'Content-Type': 'application/json',
//       },
//       body: JSON.stringify({ rate: rate.object_id, label_file_type: 'PDF', async: false }),
//     });
//     const transaction = await transactionRes.json();
//     if (transaction.status !== 'SUCCESS') {
//       return new Response(JSON.stringify({ error: 'Label purchase failed', detail: transaction }), {
//         status: 502,
//       });
//     }
//
//     const nowIso = new Date().toISOString();
//     await supabase
//       .from(table)
//       .update({
//         shipping_label_ready: true,
//         shipping_label_pdf_url: transaction.label_url,
//         shipping_label_carrier: rate.provider,
//         shipping_label_tracking_number: transaction.tracking_number,
//         shipping_label_qr_data: transaction.tracking_number,
//         shipping_qr_code: transaction.tracking_number,
//         shipping_label_created_at: nowIso,
//         shipping_status: 'label_ready',
//         estimated_delivery_at: rate.estimated_days
//           ? new Date(Date.now() + rate.estimated_days * 86400000).toISOString()
//           : null,
//         updated_at: nowIso,
//       })
//       .eq('id', requestId);
//
//     return new Response(
//       JSON.stringify({
//         labelPdfUrl: transaction.label_url,
//         carrier: rate.provider,
//         trackingNumber: transaction.tracking_number,
//         trackingUrlProvider: transaction.tracking_url_provider,
//       }),
//       { headers: { 'Content-Type': 'application/json' } },
//     );
//   } catch (e) {
//     return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
//   }
// });

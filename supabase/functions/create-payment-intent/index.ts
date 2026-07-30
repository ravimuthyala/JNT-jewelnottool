// Creates a Stripe PaymentIntent for a client/brand's accepted request and
// returns its client_secret so the app can present Stripe's payment sheet.
//
// STATUS: not active yet. lib/pages/order_details_pages.dart's "Pay Now"
// button only simulates payment while kPaymentLiveEnabled = false there.
// This function is scaffolding for when Stripe is actually wired up --
// deploy it, set STRIPE_SECRET_KEY, and flip kPaymentLiveEnabled to true.
//
// This function must own charge creation because it needs the Stripe
// *secret* key, which must never ship inside the Flutter app. The client
// only ever sees the returned client_secret.
//
// Deploy: supabase functions deploy create-payment-intent --project-ref <ref>
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_... --project-ref <ref>
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-injected by the platform.

// import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
// import Stripe from 'https://esm.sh/stripe@14?target=deno';
//
// const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
// const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!;
//
// const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
//   auth: { persistSession: false },
// });
// const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' });
//
// interface RequestBody {
//   requestId: string;
//   sourceCollection: string; // 'Client_Custom_Requests' | 'Company_Custom_Requests'
// }
//
// Deno.serve(async (req) => {
//   try {
//     const { requestId, sourceCollection }: RequestBody = await req.json();
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
//       .select('id, artist_final_amount, client_email, payment_status')
//       .eq('id', requestId)
//       .maybeSingle();
//     if (error || !row) {
//       return new Response(JSON.stringify({ error: 'Request not found' }), {
//         status: 404,
//       });
//     }
//     if (row.payment_status === 'paid') {
//       return new Response(JSON.stringify({ error: 'Already paid' }), {
//         status: 409,
//       });
//     }
//
//     const amount = Math.round(Number(row.artist_final_amount ?? 0) * 100); // cents
//     if (!amount || amount <= 0) {
//       return new Response(JSON.stringify({ error: 'No amount to charge' }), {
//         status: 400,
//       });
//     }
//
//     const paymentIntent = await stripe.paymentIntents.create({
//       amount,
//       currency: 'usd',
//       metadata: { requestId, sourceCollection, table },
//       receipt_email: row.client_email ?? undefined,
//     });
//
//     return new Response(
//       JSON.stringify({ clientSecret: paymentIntent.client_secret }),
//       { headers: { 'Content-Type': 'application/json' } },
//     );
//   } catch (e) {
//     return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
//   }
// });

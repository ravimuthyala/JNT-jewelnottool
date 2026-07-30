// Receives Stripe's payment_intent.succeeded (and related) events and is the
// ONLY place allowed to flip a request's paymentStatus to 'paid'. The client
// app must never set paymentStatus itself once this is live -- today's
// "Pay Now (Simulated)" button in order_details_pages.dart does exactly
// that, purely for testing, and must stop once real payments are enabled;
// tighten RLS on client_custom_requests/company_custom_requests to match
// (clients should lose UPDATE access to payment_status).
//
// STATUS: not active yet. Companion to create-payment-intent -- see that
// function's header for the activation steps.
//
// Deploy: supabase functions deploy stripe-webhook --project-ref <ref>
// Secrets: supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_... --project-ref <ref>
// Then register this function's URL as a webhook endpoint in the Stripe
// dashboard for the payment_intent.succeeded / payment_intent.payment_failed
// events.

// import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
// import Stripe from 'https://esm.sh/stripe@14?target=deno';
//
// const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
// const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!;
// const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;
//
// const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
//   auth: { persistSession: false },
// });
// const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' });
//
// Deno.serve(async (req) => {
//   const signature = req.headers.get('stripe-signature');
//   const body = await req.text();
//
//   let event: Stripe.Event;
//   try {
//     event = await stripe.webhooks.constructEventAsync(
//       body,
//       signature!,
//       STRIPE_WEBHOOK_SECRET,
//     );
//   } catch (e) {
//     return new Response(`Webhook signature verification failed: ${e}`, {
//       status: 400,
//     });
//   }
//
//   if (event.type === 'payment_intent.succeeded') {
//     const intent = event.data.object as Stripe.PaymentIntent;
//     const requestId = intent.metadata.requestId;
//     const table = intent.metadata.table; // 'client_custom_requests' | 'company_custom_requests'
//     const nowIso = new Date().toISOString();
//
//     if (requestId && table) {
//       await supabase
//         .from(table)
//         .update({
//           payment_status: 'paid',
//           paid_at: nowIso,
//           updated_at: nowIso,
//         })
//         .eq('id', requestId);
//       // Mirror into the row's details/payload jsonb + notify the artist
//       // the same way _simulatePayment does today in
//       // order_details_pages.dart, so the UI stays consistent regardless
//       // of which path (simulated vs real) marked it paid.
//     }
//   }
//
//   return new Response(JSON.stringify({ received: true }), {
//     headers: { 'Content-Type': 'application/json' },
//   });
// });

// Deno Edge Function. Deploy with:
//   supabase functions deploy stripe-webhook --no-verify-jwt
//
// The --no-verify-jwt flag matters: Stripe calls this URL directly and
// has no Supabase JWT to send. Authenticity here comes from verifying
// Stripe's signature (STRIPE_WEBHOOK_SECRET), not from Supabase auth.
//
// confirm-deposit is the primary, fast path (called right after the
// PaymentSheet closes). This webhook is what catches a deposit that
// succeeded on Stripe's side but never got confirmed client-side — the
// app was killed, the network dropped, whatever. credit_deposit() is
// idempotent, so if confirm-deposit already handled it, this is a
// harmless no-op.
//
// After deploying, add the webhook in the Stripe Dashboard (Developers
// → Webhooks → Add endpoint) pointing at this function's URL, listening
// for payment_intent.succeeded and payment_intent.payment_failed, then
// copy the signing secret into STRIPE_WEBHOOK_SECRET.

import { createClient } from "npm:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
  httpClient: Stripe.createFetchHttpClient(),
});

const adminClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  const body = await req.text();

  if (!signature) {
    return new Response("Missing stripe-signature header", { status: 400 });
  }

  let event: Stripe.Event;
  try {
    // constructEventAsync (not the sync constructEvent) — the sync
    // version relies on Node's crypto module, which Deno doesn't have.
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      Deno.env.get("STRIPE_WEBHOOK_SECRET")!,
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return new Response("Invalid signature", { status: 400 });
  }

  try {
    if (event.type === "payment_intent.succeeded") {
      const pi = event.data.object as Stripe.PaymentIntent;
      const userId = pi.metadata?.supabase_user_id;
      if (userId) {
        const { error } = await adminClient.rpc("credit_deposit", {
          p_user_id: userId,
          p_stripe_payment_intent_id: pi.id,
          p_amount: pi.amount / 100,
        });
        if (error) throw error;
      }
    } else if (event.type === "payment_intent.payment_failed") {
      const pi = event.data.object as Stripe.PaymentIntent;
      const { error } = await adminClient.rpc("mark_deposit_failed", {
        p_stripe_payment_intent_id: pi.id,
      });
      if (error) throw error;
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 });
  } catch (error) {
    console.error("Webhook handler error:", error);
    // 500 so Stripe retries with backoff — this was an infra hiccup on
    // our end, not a reason to give up on the event.
    return new Response("Webhook handler error", { status: 500 });
  }
});

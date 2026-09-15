// Deno Edge Function. Deploy with: supabase functions deploy create-payment-intent
//
// Called by DepositService.createPaymentIntent() when the user taps
// Continue on the amount-entry screen. Returns everything
// flutter_stripe's PaymentSheet needs: a PaymentIntent client secret, an
// ephemeral key for the customer, and the customer id.

import { createClient } from "npm:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17";
import { corsHeaders } from "../_shared/cors.ts";

// Pinned so the ephemeral key's API version always matches what this
// function expects from Stripe's responses. Safe to bump later; just
// keep it in sync with the ephemeralKeys.create() call below.
const STRIPE_API_VERSION = "2024-06-20";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: STRIPE_API_VERSION,
  httpClient: Stripe.createFetchHttpClient(),
});

const MIN_DEPOSIT = 5;
const MAX_DEPOSIT = 10000;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Client scoped to the caller's own JWT — used only to verify who's
    // asking. All privileged writes below use the service-role client.
    const authClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
    );
    const { data: { user }, error: authError } = await authClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Not authenticated" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { amount } = await req.json();
    if (typeof amount !== "number" || amount < MIN_DEPOSIT || amount > MAX_DEPOSIT) {
      return new Response(
        JSON.stringify({ error: `Amount must be between $${MIN_DEPOSIT} and $${MAX_DEPOSIT}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: profile } = await adminClient
      .from("profiles")
      .select("stripe_customer_id")
      .eq("id", user.id)
      .single();

    let customerId = profile?.stripe_customer_id as string | null;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: { supabase_user_id: user.id },
      });
      customerId = customer.id;
      await adminClient
        .from("profiles")
        .update({ stripe_customer_id: customerId })
        .eq("id", user.id);
    }

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: STRIPE_API_VERSION },
    );

    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Stripe wants cents
      currency: "usd",
      customer: customerId,
      // Lets Stripe show whatever payment methods are enabled in your
      // Dashboard (cards, Apple Pay, Google Pay, bank debits, etc.)
      // instead of hardcoding a fixed list here.
      automatic_payment_methods: { enabled: true },
      metadata: { supabase_user_id: user.id },
    });

    const { error: insertError } = await adminClient.from("deposits").insert({
      user_id: user.id,
      amount,
      currency: "usd",
      stripe_payment_intent_id: paymentIntent.id,
      status: "pending",
    });
    if (insertError) throw insertError;

    return new Response(
      JSON.stringify({
        paymentIntent: paymentIntent.client_secret,
        ephemeralKey: ephemeralKey.secret,
        customer: customerId,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: "Could not start deposit" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

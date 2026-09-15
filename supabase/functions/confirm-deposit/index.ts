// Deno Edge Function. Deploy with: supabase functions deploy confirm-deposit
//
// Called right after flutter_stripe's PaymentSheet reports success. This
// function does NOT trust that claim — it asks Stripe directly what the
// PaymentIntent's real status is, and only credits the ledger if Stripe
// itself says 'succeeded'. If the app crashes or loses connection before
// this call completes, stripe-webhook/index.ts catches it independently.

import { createClient } from "npm:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17";
import { corsHeaders } from "../_shared/cors.ts";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
  httpClient: Stripe.createFetchHttpClient(),
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
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

    const { paymentIntentId } = await req.json();
    if (typeof paymentIntentId !== "string" || !paymentIntentId) {
      return new Response(JSON.stringify({ error: "Missing paymentIntentId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Ownership check: the deposits row for this PaymentIntent must
    // belong to the caller. Without this, one user could pass another
    // user's paymentIntentId and (at best) waste a Stripe API call, or
    // if the row lookup were skipped entirely, potentially confirm
    // someone else's deposit into their own account.
    const { data: depositRow } = await adminClient
      .from("deposits")
      .select("user_id, amount")
      .eq("stripe_payment_intent_id", paymentIntentId)
      .single();

    if (!depositRow || depositRow.user_id !== user.id) {
      return new Response(JSON.stringify({ error: "Deposit not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status === "succeeded") {
      const { error: rpcError } = await adminClient.rpc("credit_deposit", {
        p_user_id: user.id,
        p_stripe_payment_intent_id: paymentIntentId,
        p_amount: depositRow.amount,
      });
      if (rpcError) throw rpcError;

      return new Response(JSON.stringify({ success: true, status: "succeeded" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (paymentIntent.status === "canceled") {
      await adminClient.rpc("mark_deposit_failed", {
        p_stripe_payment_intent_id: paymentIntentId,
      });
    }

    return new Response(
      JSON.stringify({ success: false, status: paymentIntent.status }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: "Could not confirm deposit" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// Shared across create-payment-intent and confirm-deposit. Not used by
// stripe-webhook, which Stripe's servers call directly (no browser/app
// origin involved, so no CORS headers needed there).
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

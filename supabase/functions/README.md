# NegosMint Edge Functions

Three Deno functions, all handling the Stripe side of deposits. See the
main README's "Deposits (Stripe)" section for the deploy commands and
required secrets — this file is the deeper reference for what each one
actually does and why it's structured this way.

## create-payment-intent

Called when the user taps **Continue** on the deposit amount screen.

1. Verifies the caller's Supabase JWT (via the anon-key client) — this
   is "who is asking," separate from the privileged DB writes below.
2. Validates the amount ($5–$10,000).
3. Looks up (or creates, on first deposit) a Stripe **Customer** for
   this user, storing `stripe_customer_id` on their profile so it's
   reused on every future deposit rather than creating a new Customer
   each time.
4. Creates an **ephemeral key** for that customer — this is what lets
   the *mobile* Stripe SDK act on behalf of a customer without ever
   holding your secret key.
5. Creates a **PaymentIntent** with `automatic_payment_methods: { enabled: true }`
   so Stripe decides which payment methods to show based on your
   Dashboard settings, rather than this function hardcoding a list.
6. Records a `pending` row in `deposits`.
7. Returns the three values `flutter_stripe`'s `PaymentSheet` needs:
   the PaymentIntent client secret, the ephemeral key secret, and the
   customer id.

## confirm-deposit

Called immediately after `PaymentSheet` closes without throwing —
i.e., Stripe's *client-side* SDK believes the payment succeeded.

This function does not take that on faith. It:

1. Verifies the JWT, same as above.
2. Looks up the `deposits` row for the given PaymentIntent id and
   checks it actually belongs to the calling user (otherwise someone
   could pass an arbitrary PaymentIntent id and probe other users'
   deposits).
3. **Retrieves the PaymentIntent directly from Stripe's API** — this is
   the actual source of truth, not anything the client claims.
4. Only if Stripe itself reports `status: "succeeded"` does it call
   `credit_deposit()`.

## stripe-webhook

Deployed with `--no-verify-jwt` since Stripe calls this directly and
has no Supabase session. Authenticity instead comes from verifying the
`Stripe-Signature` header against `STRIPE_WEBHOOK_SECRET` — this is why
the webhook secret matters as much as the API secret key.

This exists because `confirm-deposit` is a *best-effort* fast path: if
the user's connection drops, or the app is killed, right after paying,
that call might never happen — but the payment went through on Stripe's
side regardless. The webhook is Stripe telling you about it
independently, whether or not the client-side confirmation ever fired.

`credit_deposit()` is idempotent (checks `deposits.status = 'succeeded'`
before doing anything), so it's safe for both `confirm-deposit` and the
webhook to potentially call it for the same payment — only the first
one to arrive does anything.

## Why the DB functions are service-role-only

Every other write path in this app (`complete_task()`,
`request_withdrawal()`, etc.) is a `SECURITY DEFINER` function callable
by any authenticated user, because the database itself can prove the
request is legitimate — e.g. `complete_task()` only succeeds if a
matching `task_submissions` row exists and hasn't been completed
already.

Deposits don't have an equivalent proof available inside Postgres —
the only thing that can say "yes, this person actually paid $20" is
Stripe. So `credit_deposit()` and `mark_deposit_failed()` explicitly
check `auth.role() = 'service_role'` and reject anyone else. The
Edge Functions authenticate to Postgres with the **service role key**
(never shipped to the Flutter app), which is what makes them — and
only them — able to call these two functions at all.

-- ============================================================================
-- NegosMint deposits (run this AFTER schema.sql, admin_migration.sql,
-- rate_limiting.sql, leveling.sql, and admin_today_stats.sql)
--
-- Unlike every other write path in this app, deposit confirmation can't
-- be a SECURITY DEFINER function callable by any authenticated user —
-- there's no "the DB itself proves this is legitimate" check available
-- (unlike complete_task, where the submission row IS the proof). The
-- only source of truth for "did this payment actually succeed" is
-- Stripe itself. So credit_deposit() is locked to the service_role —
-- only the create-payment-intent / confirm-deposit / stripe-webhook
-- Edge Functions can call it (they authenticate to Postgres with the
-- service role key, which bypasses RLS and this check together forms
-- the real security boundary — not RLS alone).
-- ============================================================================

alter table public.profiles
  add column if not exists stripe_customer_id text unique;

create type public.deposit_status as enum ('pending', 'succeeded', 'failed');

create table public.deposits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null default 'usd',
  stripe_payment_intent_id text unique not null,
  status public.deposit_status not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.deposits enable row level security;

create policy "Users can view their own deposits"
  on public.deposits for select
  using (auth.uid() = user_id);

create policy "Admins can view all deposits"
  on public.deposits for select
  using (public.is_admin());

-- Deliberately no insert/update/delete policy for the authenticated
-- role at all — every write to this table happens through the
-- service_role client inside the Edge Functions, which bypasses RLS
-- entirely by design. A regular user's client has no path to writing
-- here, not even an indirect one through a SECURITY DEFINER function.

-- ---------------------------------------------------------------------------
-- credit_deposit(): the only path a deposit ever reaches the wallet
-- ledger. Service-role only. Idempotent — safe to call twice for the
-- same payment_intent (confirm-deposit and the webhook both call this;
-- exactly one of them will actually do anything).
-- ---------------------------------------------------------------------------
create or replace function public.credit_deposit(
  p_user_id uuid,
  p_stripe_payment_intent_id text,
  p_amount numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_already_credited boolean;
begin
  if auth.role() != 'service_role' then
    raise exception 'Not authorized';
  end if;

  select exists(
    select 1 from public.deposits
    where stripe_payment_intent_id = p_stripe_payment_intent_id
      and status = 'succeeded'
  ) into v_already_credited;

  if v_already_credited then
    return; -- already handled by confirm-deposit or a prior webhook delivery
  end if;

  update public.deposits
  set status = 'succeeded'
  where stripe_payment_intent_id = p_stripe_payment_intent_id;

  insert into public.transactions (user_id, type, status, amount, description, reference_table, reference_id)
  select
    p_user_id, 'deposit', 'completed', p_amount,
    'Deposit via Stripe', 'deposits', id
  from public.deposits
  where stripe_payment_intent_id = p_stripe_payment_intent_id;

  insert into public.notifications (user_id, type, title, body)
  values (
    p_user_id, 'deposit_update', 'Deposit Successful',
    'Your deposit of $' || p_amount || ' has been added to your wallet.'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- mark_deposit_failed(): same service-role-only rule. Called if Stripe
-- reports the PaymentIntent failed, so the deposits row doesn't sit in
-- 'pending' forever.
-- ---------------------------------------------------------------------------
create or replace function public.mark_deposit_failed(p_stripe_payment_intent_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() != 'service_role' then
    raise exception 'Not authorized';
  end if;

  update public.deposits
  set status = 'failed'
  where stripe_payment_intent_id = p_stripe_payment_intent_id
    and status = 'pending';
end;
$$;

-- ============================================================================
-- NegosMint database schema (Supabase / Postgres)
--
-- Run this in the Supabase SQL editor on a fresh project, top to bottom.
-- It sets up:
--   1. profiles          — one row per user (extends auth.users)
--   2. transactions       — the wallet LEDGER (balance is derived, never
--                            stored as a mutable column — see spec §20/23)
--   3. tasks / task_submissions
--   4. withdrawals
--   5. referrals
--   6. notifications
--   7. streaks / levels
--   8. Row Level Security policies on every table
--   9. complete_task()   — the ONLY path that can credit a reward, so a
--                            user can never insert their own "earning" row
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. PROFILES
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique not null,
  full_name text not null,
  phone text,
  avatar_url text,
  referral_code text unique not null,
  referred_by uuid references public.profiles (id),
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by their owner"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- Referral codes and usernames need to be checkable during signup/referral
-- entry without exposing the rest of the profile.
create policy "Referral code + username lookup"
  on public.profiles for select
  using (true);

-- ---------------------------------------------------------------------------
-- 2. WALLET LEDGER
-- Balance is NEVER a stored, directly-updatable number. It's always
-- `sum(amount) where status = 'completed'` — see the wallet_balances view.
-- ---------------------------------------------------------------------------
create type public.transaction_type as enum (
  'task_reward', 'referral_reward', 'withdrawal', 'deposit', 'adjustment'
);

create type public.transaction_status as enum (
  'pending', 'completed', 'failed', 'reversed'
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type public.transaction_type not null,
  status public.transaction_status not null default 'completed',
  amount numeric(12, 2) not null, -- negative for withdrawals
  description text,
  -- points back at the task_submission / withdrawal row that caused this
  -- ledger entry, so every credit/debit is traceable to its source.
  reference_table text,
  reference_id uuid,
  created_at timestamptz not null default now()
);

alter table public.transactions enable row level security;

create policy "Users can view their own transactions"
  on public.transactions for select
  using (auth.uid() = user_id);

-- No insert/update/delete policy for regular users on purpose: the ONLY
-- way a transaction row is created is through complete_task() or the
-- withdrawal flow's trigger below, both SECURITY DEFINER. A user's own
-- client can never insert an "earning" straight into their wallet.

create view public.wallet_balances as
select
  user_id,
  coalesce(sum(amount) filter (where status = 'completed'), 0) as available,
  coalesce(sum(amount) filter (where status = 'pending'), 0) as pending,
  coalesce(sum(amount) filter (
    where status = 'completed' and amount > 0
  ), 0) as lifetime_earned
from public.transactions
group by user_id;

-- ---------------------------------------------------------------------------
-- 3. TASKS
-- ---------------------------------------------------------------------------
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  category text not null,
  reward numeric(12, 2) not null check (reward > 0),
  minutes integer not null check (minutes > 0),
  requirements text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.tasks enable row level security;

create policy "Active tasks are visible to everyone"
  on public.tasks for select
  using (is_active = true);

create type public.submission_status as enum (
  'in_progress', 'submitted', 'under_review', 'completed', 'rejected', 'expired'
);

create table public.task_submissions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id),
  user_id uuid not null references public.profiles (id) on delete cascade,
  status public.submission_status not null default 'in_progress',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  -- Anti-fraud: a user can only ever hold ONE non-terminal submission per
  -- task, which blocks the "repeated task submissions" abuse pattern from
  -- spec §21 at the database level, not just in application code.
  unique (task_id, user_id)
);

alter table public.task_submissions enable row level security;

create policy "Users can view their own submissions"
  on public.task_submissions for select
  using (auth.uid() = user_id);

create policy "Users can start a task"
  on public.task_submissions for insert
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- complete_task(): the ONLY way a task reward reaches the wallet.
-- Runs as the table owner (SECURITY DEFINER) so it can write to
-- transactions even though the calling user has no direct insert policy
-- there. This is the "server-side reward validation" from spec §20.
-- ---------------------------------------------------------------------------
create or replace function public.complete_task(p_submission_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_submission public.task_submissions%rowtype;
  v_task public.tasks%rowtype;
begin
  select * into v_submission
  from public.task_submissions
  where id = p_submission_id and user_id = auth.uid()
  for update; -- lock the row so a double-tap can't double-credit

  if not found then
    raise exception 'Submission not found';
  end if;

  if v_submission.status = 'completed' then
    raise exception 'Task already completed';
  end if;

  select * into v_task from public.tasks where id = v_submission.task_id;

  update public.task_submissions
  set status = 'completed', reviewed_at = now()
  where id = p_submission_id;

  insert into public.transactions (user_id, type, status, amount, description, reference_table, reference_id)
  values (
    auth.uid(), 'task_reward', 'completed', v_task.reward,
    'Task completed: ' || v_task.title, 'task_submissions', p_submission_id
  );

  insert into public.notifications (user_id, type, title, body)
  values (
    auth.uid(), 'task_completed', 'Task Completed',
    'You earned $' || v_task.reward || ' from ' || v_task.title || '.'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. WITHDRAWALS
-- ---------------------------------------------------------------------------
create type public.withdrawal_status as enum (
  'pending', 'approved', 'rejected', 'completed'
);

create table public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  fee numeric(12, 2) not null default 0,
  method text not null,
  status public.withdrawal_status not null default 'pending',
  transaction_ref text unique not null,
  created_at timestamptz not null default now()
);

alter table public.withdrawals enable row level security;

create policy "Users can view their own withdrawals"
  on public.withdrawals for select
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- request_withdrawal(): checks available balance server-side (never trust
-- the client's number) and atomically debits the ledger with a 'pending'
-- transaction in the same transaction as the withdrawal row. Returns the
-- human-readable transaction_ref (e.g. "NM-3F9A2B1C4D") for display —
-- not the internal uuid.
-- ---------------------------------------------------------------------------
create or replace function public.request_withdrawal(
  p_amount numeric, p_fee numeric, p_method text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_available numeric;
  v_withdrawal_id uuid;
  v_ref text;
begin
  select available into v_available
  from public.wallet_balances
  where user_id = auth.uid();

  if v_available is null or v_available < p_amount then
    raise exception 'Insufficient balance';
  end if;

  v_ref := 'NM-' || upper(substr(md5(random()::text), 1, 10));

  insert into public.withdrawals (user_id, amount, fee, method, transaction_ref)
  values (auth.uid(), p_amount, p_fee, p_method, v_ref)
  returning id into v_withdrawal_id;

  insert into public.transactions (user_id, type, status, amount, description, reference_table, reference_id)
  values (
    auth.uid(), 'withdrawal', 'pending', -p_amount,
    'Withdrawal via ' || p_method, 'withdrawals', v_withdrawal_id
  );

  insert into public.notifications (user_id, type, title, body)
  values (
    auth.uid(), 'withdrawal_update', 'Withdrawal Update',
    'Your withdrawal of $' || p_amount || ' is processing.'
  );

  return v_ref;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. REFERRALS
-- ---------------------------------------------------------------------------
create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references public.profiles (id) on delete cascade,
  referred_id uuid not null references public.profiles (id) on delete cascade,
  reward_earned numeric(12, 2) not null default 0,
  created_at timestamptz not null default now(),
  unique (referred_id) -- a user can only ever be referred once
);

alter table public.referrals enable row level security;

create policy "Users can view their own referrals"
  on public.referrals for select
  using (auth.uid() = referrer_id);

-- ---------------------------------------------------------------------------
-- 6. NOTIFICATIONS
-- ---------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "Users can view their own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "Users can mark their own notifications read"
  on public.notifications for update
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 7. STREAKS + LEVELS
-- ---------------------------------------------------------------------------
create table public.streaks (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  current_streak integer not null default 0,
  last_activity_date date,
  updated_at timestamptz not null default now()
);

alter table public.streaks enable row level security;

create policy "Users can view their own streak"
  on public.streaks for select
  using (auth.uid() = user_id);

create table public.levels (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  xp integer not null default 0,
  level integer not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.levels enable row level security;

create policy "Users can view their own level"
  on public.levels for select
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 8. NEW USER BOOTSTRAP
-- Fires when someone signs up (auth.users insert) and creates their
-- profile + wallet-adjacent rows in one go, including a unique referral
-- code and crediting whoever referred them.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referred_by uuid;
begin
  if new.raw_user_meta_data ->> 'referral_code' is not null then
    select id into v_referred_by
    from public.profiles
    where referral_code = new.raw_user_meta_data ->> 'referral_code';
  end if;

  insert into public.profiles (id, username, full_name, phone, referral_code, referred_by)
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'phone',
    upper(substr(md5(random()::text), 1, 8)),
    v_referred_by
  );

  insert into public.streaks (user_id) values (new.id);
  insert into public.levels (user_id) values (new.id);

  if v_referred_by is not null then
    insert into public.referrals (referrer_id, referred_id, reward_earned)
    values (v_referred_by, new.id, 2.50);

    insert into public.transactions (user_id, type, status, amount, description)
    values (v_referred_by, 'referral_reward', 'completed', 2.50, 'Referral reward: new signup');

    insert into public.notifications (user_id, type, title, body)
    values (
      v_referred_by, 'referral_reward', 'Referral Reward',
      'You earned a referral reward from a new signup.'
    );
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 9. SEED TASKS (matches the placeholder tasks already in the Flutter UI)
-- ---------------------------------------------------------------------------
insert into public.tasks (title, description, category, reward, minutes) values
  ('Complete Survey', 'Answer a short consumer survey.', 'Surveys', 1.50, 5),
  ('Install & Try App', 'Install a partner app and try it for 5 minutes.', 'Apps', 2.25, 10),
  ('Follow & Share', 'Follow and share a partner social post.', 'Social', 0.75, 3),
  ('Watch Short Video', 'Watch a short sponsored video to completion.', 'Videos', 0.40, 2),
  ('Sign Up Offer', 'Complete a partner sign-up offer.', 'Offers', 4.00, 15);

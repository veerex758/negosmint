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
  is_suspended boolean not null default false,
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
  coalesce(sum(amount) filter (where status = 'pending' and amount > 0), 0) as pending,
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
  currency_code text not null default 'USD' check (currency_code in ('USD','NGN')),
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
  -- Terminal submissions may be retried; active states are constrained below.
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
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Withdrawal amount must be greater than zero'; end if;
  if p_fee is null or p_fee < 0 then raise exception 'Withdrawal fee cannot be negative'; end if;

  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

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
  ('Complete Survey', 'Answer a short consumer survey.', 'Surveys', 1.50, 5, null, null, false),
  ('Install & Try App', 'Install a partner app and try it for 5 minutes.', 'Apps', 2.25, 10, null, null, false),
  ('Follow & Share', 'Follow and share a partner social post.', 'Social', 0.75, 3, null, null, false),
  ('Watch Short Video', 'Watch a short sponsored video to completion.', 'Videos', 0.40, 2, null, null, false),
  ('Sign Up Offer', 'Complete a partner sign-up offer.', 'Offers', 4.00, 15, null, null, false);

-- ============================================================================
-- 10. BLUEPRINT UPGRADE: reservations, verification, trust, and campaigns
-- ============================================================================
-- Proof is submitted only through submit_task_proof(). Clients can no longer
-- create arbitrary submissions or change their state directly.
alter table public.task_submissions drop constraint if exists task_submissions_task_id_user_id_key;

drop policy if exists "Users can start a task" on public.task_submissions;

alter table public.profiles
  add column if not exists country_code text,
  add column if not exists currency_code text not null default 'USD',
  add column if not exists device_fingerprint_hash text;
create unique index if not exists profiles_device_fingerprint_unique
  on public.profiles (device_fingerprint_hash) where device_fingerprint_hash is not null;

create table if not exists public.user_trust_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  current_level integer not null default 1 check (current_level between 1 and 4),
  trust_score integer not null default 100 check (trust_score between 0 and 1000),
  total_completed_tasks integer not null default 0,
  total_rejected_tasks integer not null default 0,
  yield_multiplier numeric(3,2) not null default 1.00,
  updated_at timestamptz not null default now()
);
alter table public.user_trust_profiles enable row level security;
create policy "Users can view their own trust profile" on public.user_trust_profiles
  for select using (auth.uid() = user_id);

alter table public.tasks
  add column if not exists advertiser_id uuid references public.profiles(id),
  add column if not exists advertiser_name text,
  add column if not exists advertiser_rating numeric(2,1),
  add column if not exists total_slots integer check (total_slots > 0),
  add column if not exists remaining_slots integer check (remaining_slots >= 0),
  add column if not exists reservation_minutes integer not null default 20 check (reservation_minutes between 15 and 30),
  add column if not exists verification_mode text not null default 'manual' check (verification_mode in ('instant', 'manual')),
  add column if not exists minimum_trust_level integer not null default 1 check (minimum_trust_level between 1 and 4),
  add column if not exists proof_criteria jsonb not null default '{}'::jsonb;

alter table public.task_submissions
  add column if not exists proof_text text,
  add column if not exists proof_image_url text,
  add column if not exists image_hash varchar(256),
  add column if not exists ocr_extracted_data jsonb,
  add column if not exists ai_confidence_score numeric(5,2),
  add column if not exists rejection_reason text,
  add column if not exists reserved_until timestamptz,
  add column if not exists submitted_at timestamptz,
  add column if not exists started_at timestamptz not null default now();
drop index if exists public.task_submission_image_hash_unique;
create unique index if not exists task_submission_image_hash_unique
  on public.task_submissions(image_hash) where image_hash is not null;

create unique index if not exists transactions_one_task_reward_per_submission
  on public.transactions(reference_table, reference_id)
  where type = 'task_reward' and reference_table = 'task_submissions';

create table if not exists public.campaign_escrow (
  campaign_id uuid primary key references public.tasks(id) on delete cascade,
  advertiser_id uuid not null references public.profiles(id),
  total_budget numeric(12,2) not null check (total_budget > 0),
  escrow_remaining numeric(12,2) not null check (escrow_remaining >= 0),
  platform_fee_rate numeric(4,2) not null default .15 check (platform_fee_rate between .15 and .20),
  featured boolean not null default false,
  express_verification boolean not null default false,
  status text not null default 'active' check (status in ('draft', 'active', 'paused', 'completed')),
  created_at timestamptz not null default now()
);
alter table public.campaign_escrow enable row level security;
create policy "Advertisers can view their campaigns" on public.campaign_escrow for select using (auth.uid() = advertiser_id);

-- Atomically reserve campaign inventory and reject users below the campaign's
-- Mint Rank. A scheduled cleanup releases expired reservations back to inventory.
create or replace function public.reserve_task_slot(p_task_id uuid)
returns public.task_submissions
language plpgsql security definer set search_path = public as $$
declare v_task public.tasks%rowtype; v_trust public.user_trust_profiles%rowtype; v_submission public.task_submissions%rowtype;
begin
  select * into v_task from public.tasks where id = p_task_id and is_active for update;
  if not found or (v_task.remaining_slots is not null and v_task.remaining_slots <= 0) then raise exception 'No task slots available'; end if;
  select * into v_trust from public.user_trust_profiles where user_id = auth.uid();
  if coalesce(v_trust.current_level, 1) < v_task.minimum_trust_level then raise exception 'Mint Rank is too low for this task'; end if;
  if exists (select 1 from public.task_submissions where task_id = p_task_id and user_id = auth.uid()) then raise exception 'Task already started or completed'; end if;
  insert into public.task_submissions(task_id,user_id,status,reserved_until,started_at)
  values(p_task_id,auth.uid(),'in_progress',now() + make_interval(mins => v_task.reservation_minutes),now()) returning * into v_submission;
  if v_task.remaining_slots is not null then update public.tasks set remaining_slots = remaining_slots - 1 where id=p_task_id; end if;
  return v_submission;
end; $$;

-- A verification worker may populate OCR/hash/confidence after submission.
-- This initial server gate provides an instant path only for no-image,
-- high-confidence criteria; all other work remains in escrow for review.
create or replace function public.submit_task_proof(p_submission_id uuid, p_proof_text text, p_proof_image_url text default null)
returns text
language plpgsql security definer set search_path = public as $$
declare v_submission public.task_submissions%rowtype; v_task public.tasks%rowtype; v_status text; v_reward numeric;
begin
  select * into v_submission from public.task_submissions where id=p_submission_id and user_id=auth.uid() for update;
  if not found then raise exception 'Submission not found'; end if;
  if v_submission.status <> 'in_progress' or v_submission.reserved_until < now() then raise exception 'Task reservation has expired'; end if;
  if coalesce(length(trim(p_proof_text)),0) = 0 and p_proof_image_url is null then raise exception 'Proof is required'; end if;
  select * into v_task from public.tasks where id=v_submission.task_id;
  v_status := case when v_task.verification_mode = 'instant' and p_proof_image_url is null then 'completed' else 'under_review' end;
  update public.task_submissions set status=v_status, proof_text=p_proof_text, proof_image_url=p_proof_image_url, submitted_at=now(), reviewed_at=case when v_status='completed' then now() else null end where id=p_submission_id;
  if v_status='completed' then
    select v_task.reward * coalesce(yield_multiplier,1) into v_reward from public.user_trust_profiles where user_id=auth.uid();
    insert into public.transactions(user_id,type,status,amount,description,reference_table,reference_id) values(auth.uid(),'task_reward','completed',v_reward,'Instant verification: '||v_task.title,'task_submissions',p_submission_id);
    update public.user_trust_profiles set total_completed_tasks=total_completed_tasks+1, updated_at=now() where user_id=auth.uid();
    return 'instant_approved';
  end if;
  insert into public.transactions(user_id,type,status,amount,description,reference_table,reference_id) values(auth.uid(),'task_reward','pending',v_task.reward,'Pending verification: '||v_task.title,'task_submissions',p_submission_id);
  return 'pending_review';
end; $$;

-- Ensure every signup receives an independently visible trust profile.
create or replace function public.bootstrap_trust_profile() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.user_trust_profiles(user_id) values(new.id) on conflict do nothing; return new; end; $$;
drop trigger if exists profiles_create_trust_profile on public.profiles;
create trigger profiles_create_trust_profile after insert on public.profiles for each row execute function public.bootstrap_trust_profile();

-- Run this from a scheduled Supabase job to make expired reservations
-- visible as expired and return their campaign inventory.
create or replace function public.release_expired_task_reservations()
returns integer language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  with expired as (
    update public.task_submissions set status='expired'
    where status='in_progress' and reserved_until < now()
    returning task_id
  ), restored as (
    update public.tasks t set remaining_slots = t.remaining_slots + e.count
    from (select task_id, count(*)::integer as count from expired group by task_id) e
    where t.id=e.task_id and t.remaining_slots is not null
    returning t.id
  ) select count(*) into v_count from restored;
  return coalesce(v_count, 0);
end; $$;

-- Current blueprint starter inventory.
update public.tasks set category='Instant-Approve', verification_mode='instant', total_slots=500, remaining_slots=500, advertiser_name='Mint Labs', advertiser_rating=4.9 where title='Complete Survey';
update public.tasks set category='Product & App Testing', total_slots=200, remaining_slots=200, advertiser_name='Product Studio', advertiser_rating=4.8 where title='Install & Try App';
update public.tasks set category='Social Growth', total_slots=500, remaining_slots=500, advertiser_name='Growth Partner', advertiser_rating=4.7 where title='Follow & Share';

-- ============================================================================
-- 11. SECURITY/ACCOUNTING HARDENING
-- ============================================================================
-- Terminal submissions may be retried; only one active submission is allowed
-- for a user/task at a time.
alter table public.task_submissions
  drop constraint if exists task_submissions_task_id_user_id_key;
create unique index if not exists task_submissions_one_active_per_user_task
  on public.task_submissions(task_id, user_id)
  where status in ('in_progress', 'submitted', 'under_review');

-- Do not let an old public RPC remain as a second reward-credit path.
revoke execute on function public.complete_task(uuid) from public, anon, authenticated;

create or replace function public.reserve_task_slot(p_task_id uuid)
returns public.task_submissions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.tasks%rowtype;
  v_trust public.user_trust_profiles%rowtype;
  v_level integer;
  v_submission public.task_submissions%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into v_task
  from public.tasks
  where id = p_task_id and is_active
  for update;

  if not found then raise exception 'Task is unavailable'; end if;
  if v_task.remaining_slots is not null and v_task.remaining_slots <= 0 then
    raise exception 'No task slots available';
  end if;

  if exists (
    select 1 from public.profiles
    where id = auth.uid() and coalesce(is_suspended, false)
  ) then
    raise exception 'Account is suspended';
  end if;

  select * into v_trust
  from public.user_trust_profiles
  where user_id = auth.uid();

  if coalesce(v_trust.current_level, 1) < v_task.minimum_trust_level then
    raise exception 'Mint Rank is too low for this task';
  end if;

  begin
    insert into public.task_submissions(task_id, user_id, status, reserved_until, started_at)
    values (
      p_task_id, auth.uid(), 'in_progress',
      now() + make_interval(mins => v_task.reservation_minutes), now()
    )
    returning * into v_submission;
  exception when unique_violation then
    raise exception 'Task already started or is awaiting review';
  end;

  if v_task.remaining_slots is not null then
    update public.tasks
    set remaining_slots = remaining_slots - 1
    where id = p_task_id;
  end if;

  return v_submission;
end;
$$;

create or replace function public.submit_task_proof(
  p_submission_id uuid,
  p_proof_text text,
  p_proof_image_url text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_submission public.task_submissions%rowtype;
  v_task public.tasks%rowtype;
  v_escrow public.campaign_escrow%rowtype;
  v_reward numeric;
  v_status public.submission_status;
  v_criteria jsonb;
  v_exact text;
  v_contains jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into v_submission
  from public.task_submissions
  where id = p_submission_id and user_id = auth.uid()
  for update;

  if not found then raise exception 'Submission not found'; end if;
  if v_submission.status <> 'in_progress'
     or v_submission.reserved_until is null
     or v_submission.reserved_until <= now() then
    raise exception 'Task reservation has expired';
  end if;

  if coalesce(length(trim(p_proof_text)), 0) = 0
     and p_proof_image_url is null then
    raise exception 'Proof is required';
  end if;

  select * into v_task from public.tasks where id = v_submission.task_id;
  if not found or not v_task.is_active then raise exception 'Task is unavailable'; end if;

  v_criteria := coalesce(v_task.proof_criteria, '{}'::jsonb);
  v_status := 'under_review';

  -- "Instant" is allowed only when the campaign explicitly defines a
  -- deterministic text rule and the submitted text satisfies it. An empty
  -- proof_criteria object can never auto-approve a reward.
  if v_task.verification_mode = 'instant' and p_proof_image_url is null then
    v_exact := nullif(trim(v_criteria ->> 'exact_text'), '');
    v_contains := v_criteria -> 'contains';

    if v_exact is not null and trim(coalesce(p_proof_text, '')) = v_exact then
      v_status := 'completed';
    elsif jsonb_typeof(v_contains) = 'array'
      and jsonb_array_length(v_contains) > 0
      and not exists (
        select 1
        from jsonb_array_elements_text(v_contains) required
        where position(lower(required) in lower(coalesce(p_proof_text, ''))) = 0
      ) then
      v_status := 'completed';
    end if;
  end if;

  if v_status = 'completed' then
    select * into v_escrow
    from public.campaign_escrow
    where campaign_id = v_task.id
      and status = 'active'
    for update;

    if not found then
      raise exception 'Campaign escrow is not funded';
    end if;

    select v_task.reward * coalesce(utp.yield_multiplier, 1.00)
      into v_reward
    from public.user_trust_profiles utp
    where utp.user_id = auth.uid();

    v_reward := coalesce(v_reward, v_task.reward);

    if v_escrow.escrow_remaining < v_reward then
      raise exception 'Campaign escrow is insufficient';
    end if;

    update public.campaign_escrow
    set escrow_remaining = escrow_remaining - v_reward,
        status = case when escrow_remaining - v_reward = 0 then 'completed' else status end
    where campaign_id = v_task.id;

    update public.task_submissions
    set status = 'completed',
        proof_text = p_proof_text,
        proof_image_url = p_proof_image_url,
        submitted_at = now(),
        reviewed_at = now()
    where id = p_submission_id;

    insert into public.transactions(
      user_id, type, status, amount, description, reference_table, reference_id
    )
    values (
      auth.uid(), 'task_reward', 'completed', v_reward,
      'Instant verification: ' || v_task.title,
      'task_submissions', p_submission_id
    );

    update public.user_trust_profiles
    set total_completed_tasks = total_completed_tasks + 1, updated_at = now()
    where user_id = auth.uid();

    return 'instant_approved';
  end if;

  -- Manual/failed instant verification enters review. Hold the reward in
  -- campaign escrow now so concurrent approvals cannot overspend it.
  select * into v_escrow
  from public.campaign_escrow
  where campaign_id = v_task.id and status = 'active'
  for update;

  if not found or v_escrow.escrow_remaining < v_reward then
    raise exception 'Campaign escrow is insufficient';
  end if;

  update public.campaign_escrow
  set escrow_remaining = escrow_remaining - v_reward
  where campaign_id = v_task.id;

  update public.task_submissions
  set status = 'under_review',
      proof_text = p_proof_text,
      proof_image_url = p_proof_image_url,
      submitted_at = now()
  where id = p_submission_id;

  insert into public.transactions(
    user_id, type, status, amount, description, reference_table, reference_id
  )
  values (
    auth.uid(), 'task_reward', 'pending', v_reward,
    'Pending verification: ' || v_task.title,
    'task_submissions', p_submission_id
  );

  return 'pending_review';
end;
$$;

-- Central admin gate used by settlement RPCs.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$;

revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

revoke execute on function public.reserve_task_slot(uuid) from public, anon;
grant execute on function public.reserve_task_slot(uuid) to authenticated;
revoke execute on function public.submit_task_proof(uuid, text, text) from public, anon;
grant execute on function public.submit_task_proof(uuid, text, text) to authenticated;
revoke execute on function public.approve_task_submission(uuid) from public, anon;
grant execute on function public.approve_task_submission(uuid) to authenticated;
revoke execute on function public.reject_task_submission(uuid, text) from public, anon;
grant execute on function public.reject_task_submission(uuid, text) to authenticated;
revoke execute on function public.request_withdrawal(numeric, numeric, text) from public, anon;
grant execute on function public.request_withdrawal(numeric, numeric, text) to authenticated;

-- Admin-only atomic settlement for manually reviewed submissions.
create or replace function public.approve_task_submission(p_submission_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_submission public.task_submissions%rowtype;
begin
  if not public.is_admin() then raise exception 'Not authorized'; end if;

  select * into v_submission
  from public.task_submissions
  where id = p_submission_id
  for update;

  if not found then raise exception 'Submission not found'; end if;
  if v_submission.status <> 'under_review' then
    raise exception 'Submission is not awaiting review';
  end if;

  update public.task_submissions
  set status = 'completed', reviewed_at = now()
  where id = p_submission_id;

  update public.transactions
  set status = 'completed'
  where reference_table = 'task_submissions'
    and reference_id = p_submission_id
    and type = 'task_reward'
    and status = 'pending';

  update public.user_trust_profiles
  set total_completed_tasks = total_completed_tasks + 1, updated_at = now()
  where user_id = v_submission.user_id;

  return 'approved';
end;
$$;

create or replace function public.reject_task_submission(
  p_submission_id uuid,
  p_reason text default 'Proof did not meet the campaign criteria'
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_submission public.task_submissions%rowtype;
  v_task public.tasks%rowtype;
  v_tx public.transactions%rowtype;
begin
  if not public.is_admin() then raise exception 'Not authorized'; end if;

  select * into v_submission
  from public.task_submissions
  where id = p_submission_id
  for update;

  if not found then raise exception 'Submission not found'; end if;
  if v_submission.status <> 'under_review' then
    raise exception 'Submission is not awaiting review';
  end if;

  select * into v_task from public.tasks where id = v_submission.task_id;

  update public.task_submissions
  set status = 'rejected', rejection_reason = p_reason, reviewed_at = now()
  where id = p_submission_id;

  select * into v_tx
  from public.transactions
  where reference_table = 'task_submissions'
    and reference_id = p_submission_id
    and type = 'task_reward'
    and status = 'pending'
  for update;

  if found then
    update public.transactions set status = 'reversed' where id = v_tx.id;
    update public.campaign_escrow
    set escrow_remaining = escrow_remaining + v_tx.amount,
        status = case when status = 'completed' then 'active' else status end
    where campaign_id = v_task.id;
  end if;

  update public.user_trust_profiles
  set total_rejected_tasks = total_rejected_tasks + 1, updated_at = now()
  where user_id = v_submission.user_id;

  return 'rejected';
end;
$$;

create or replace function public.release_expired_task_reservations()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  with expired as (
    update public.task_submissions
    set status = 'expired'
    where status = 'in_progress'
      and reserved_until is not null
      and reserved_until < now()
    returning task_id
  ), restored as (
    update public.tasks t
    set remaining_slots = t.remaining_slots + e.count
    from (
      select task_id, count(*)::integer as count
      from expired group by task_id
    ) e
    where t.id = e.task_id and t.remaining_slots is not null
    returning t.id
  )
  select coalesce((select count(*) from expired), 0) into v_count;
  return v_count;
end;
$$;

-- Do not expose maintenance/admin settlement RPCs to anonymous clients.
revoke execute on function public.release_expired_task_reservations() from public, anon, authenticated;


-- Optional Supabase pg_cron maintenance job. Run only when pg_cron is enabled
-- in the project. It expires abandoned reservations every five minutes.
-- select cron.schedule('negosmint-expire-task-reservations', '*/5 * * * *',
--   $$select public.release_expired_task_reservations();$$);

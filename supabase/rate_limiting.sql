-- ============================================================================
-- NegosMint rate limiting (run this AFTER schema.sql and admin_migration.sql)
--
-- schema.sql already blocks the "free" cases of fraud — a unique
-- constraint can't be bypassed by faster requests. This file adds the
-- cases that need an actual rate check: nothing stops a script from
-- calling complete_task() in a tight loop across many *different* tasks,
-- or spamming withdrawal requests. Both are now checked server-side, so
-- a modified client gains nothing by skipping the app's own throttling.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- TASK COMPLETION RATE LIMIT
-- No real user finishes tasks fast enough to hit this; a script looping
-- complete_task() across many task_submissions would. Replaces
-- complete_task() from schema.sql with the same body plus one check.
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
  v_recent_completions integer;
begin
  select count(*) into v_recent_completions
  from public.task_submissions
  where user_id = auth.uid()
    and status = 'completed'
    and reviewed_at > now() - interval '1 hour';

  if v_recent_completions >= 20 then
    raise exception 'Too many tasks completed recently — try again later';
  end if;

  select * into v_submission
  from public.task_submissions
  where id = p_submission_id and user_id = auth.uid()
  for update;

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
-- WITHDRAWAL RATE LIMIT
-- One pending withdrawal at a time (stops someone from queuing several
-- requests against the same balance before the first is reviewed), plus
-- a simple daily count cap. Replaces request_withdrawal() from
-- admin_migration.sql with the same body plus these two checks.
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
  v_suspended boolean;
  v_pending_count integer;
  v_today_count integer;
begin
  select is_suspended into v_suspended
  from public.profiles where id = auth.uid();

  if v_suspended then
    raise exception 'Account is suspended';
  end if;

  select count(*) into v_pending_count
  from public.withdrawals
  where user_id = auth.uid() and status = 'pending';

  if v_pending_count > 0 then
    raise exception 'You already have a pending withdrawal';
  end if;

  select count(*) into v_today_count
  from public.withdrawals
  where user_id = auth.uid() and created_at > now() - interval '24 hours';

  if v_today_count >= 5 then
    raise exception 'Withdrawal limit reached for today — try again tomorrow';
  end if;

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
-- SIGNUP VELOCITY
-- Flags (rather than blocks — false positives on shared wifi/NAT are
-- common) an unusually high number of new accounts crediting the same
-- referral code in a short window, by writing an admin_action-style row
-- an admin can review. This does not stop the signup; it's a signal,
-- not a rule, since blocking outright would be easy to get wrong.
-- ---------------------------------------------------------------------------
create table if not exists public.fraud_flags (
  id uuid primary key default gen_random_uuid(),
  flag_type text not null,
  subject_id uuid not null,
  detail text,
  created_at timestamptz not null default now()
);

alter table public.fraud_flags enable row level security;

create policy "Admins can view fraud flags"
  on public.fraud_flags for select
  using (public.is_admin());

create or replace function public.check_referral_velocity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recent_count integer;
begin
  if new.referred_by is not null then
    select count(*) into v_recent_count
    from public.profiles
    where referred_by = new.referred_by
      and created_at > now() - interval '1 hour';

    if v_recent_count >= 5 then
      insert into public.fraud_flags (flag_type, subject_id, detail)
      values (
        'referral_velocity', new.referred_by,
        v_recent_count || ' signups on this referral code in the last hour'
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists on_profile_created_check_velocity on public.profiles;
create trigger on_profile_created_check_velocity
  after insert on public.profiles
  for each row execute function public.check_referral_velocity();

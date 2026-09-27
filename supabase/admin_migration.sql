-- ============================================================================
-- NegosMint admin support (run this AFTER schema.sql, once, in the SQL editor)
--
-- Adds what the admin dashboard needs on top of the base schema:
--   - profiles.is_suspended, so an admin can suspend an account
--   - is_admin() — a helper used by every admin policy below
--   - "admins can see/do everything" policies, layered alongside the
--     existing per-user policies (RLS policies are OR'd together, so a
--     regular user's access is completely unaffected by these additions)
--   - approve/reject_withdrawal() — the only path that can move a
--     withdrawal out of 'pending', so that transition is always audited
--   - suspension enforcement: a suspended user can no longer start tasks
--     or request withdrawals, checked server-side in the functions that
--     already gate those actions
-- ============================================================================

alter table public.profiles
  add column if not exists is_suspended boolean not null default false;

-- ---------------------------------------------------------------------------
-- is_admin(): the single source of truth every admin policy below checks.
-- SECURITY DEFINER + a fixed search_path so it can't be tricked by a
-- search_path change, and STABLE so Postgres can cache it within a query.
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (select is_admin from public.profiles where id = auth.uid()),
    false
  );
$$;

-- ---------------------------------------------------------------------------
-- PROFILES — admins can see and suspend/verify any account
-- ---------------------------------------------------------------------------
create policy "Admins can view all profiles"
  on public.profiles for select
  using (public.is_admin());

create policy "Admins can update any profile"
  on public.profiles for update
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- TRANSACTIONS — admins can see every ledger entry (for analytics/revenue)
-- ---------------------------------------------------------------------------
create policy "Admins can view all transactions"
  on public.transactions for select
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- TASKS — admins can see inactive tasks too, and create/edit/disable them
-- ---------------------------------------------------------------------------
create policy "Admins can view all tasks"
  on public.tasks for select
  using (public.is_admin());

create policy "Admins can insert tasks"
  on public.tasks for insert
  with check (public.is_admin());

create policy "Admins can update tasks"
  on public.tasks for update
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- TASK SUBMISSIONS — admins can see every submission (for review queues)
-- ---------------------------------------------------------------------------
create policy "Admins can view all submissions"
  on public.task_submissions for select
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- WITHDRAWALS — admins can see every request; approve/reject go through
-- dedicated functions below rather than a raw update policy, so every
-- status change is validated and leaves a consistent ledger entry.
-- ---------------------------------------------------------------------------
create policy "Admins can view all withdrawals"
  on public.withdrawals for select
  using (public.is_admin());

create or replace function public.approve_withdrawal(p_withdrawal_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_withdrawal public.withdrawals%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Not authorized';
  end if;

  select * into v_withdrawal
  from public.withdrawals
  where id = p_withdrawal_id
  for update;

  if not found then
    raise exception 'Withdrawal not found';
  end if;
  if v_withdrawal.status != 'pending' then
    raise exception 'Withdrawal already %', v_withdrawal.status;
  end if;

  update public.withdrawals
  set status = 'completed'
  where id = p_withdrawal_id;

  update public.transactions
  set status = 'completed'
  where reference_table = 'withdrawals' and reference_id = p_withdrawal_id;

  insert into public.notifications (user_id, type, title, body)
  values (
    v_withdrawal.user_id, 'withdrawal_update', 'Withdrawal Update',
    'Your withdrawal of $' || v_withdrawal.amount || ' was approved.'
  );
end;
$$;

create or replace function public.reject_withdrawal(p_withdrawal_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_withdrawal public.withdrawals%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Not authorized';
  end if;

  select * into v_withdrawal
  from public.withdrawals
  where id = p_withdrawal_id
  for update;

  if not found then
    raise exception 'Withdrawal not found';
  end if;
  if v_withdrawal.status != 'pending' then
    raise exception 'Withdrawal already %', v_withdrawal.status;
  end if;

  update public.withdrawals
  set status = 'rejected'
  where id = p_withdrawal_id;

  -- Reverse the ledger hold — the pending debit never actually left, so
  -- credit it back rather than deleting the original row (the ledger is
  -- append-only; corrections are new rows, never edits or deletes).
  update public.transactions
  set status = 'reversed'
  where reference_table = 'withdrawals' and reference_id = p_withdrawal_id;

  insert into public.transactions (user_id, type, status, amount, description, reference_table, reference_id)
  values (
    v_withdrawal.user_id, 'adjustment', 'completed', v_withdrawal.amount,
    'Withdrawal rejected — funds returned', 'withdrawals', p_withdrawal_id
  );

  insert into public.notifications (user_id, type, title, body)
  values (
    v_withdrawal.user_id, 'withdrawal_update', 'Withdrawal Update',
    'Your withdrawal of $' || v_withdrawal.amount || ' was rejected and refunded.'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- ADMIN ANALYTICS — one function, one round trip, matches spec §22
-- (Total Users, Active Users, Tasks Completed, Total Rewards,
-- Total Withdrawals, Revenue).
-- ---------------------------------------------------------------------------
create or replace function public.admin_analytics()
returns table (
  total_users bigint,
  active_users bigint,
  tasks_completed bigint,
  total_rewards numeric,
  total_withdrawals numeric,
  revenue numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Not authorized';
  end if;

  return query
  select
    (select count(*) from public.profiles),
    (select count(distinct user_id) from public.transactions
       where created_at > now() - interval '30 days'),
    (select count(*) from public.task_submissions where status = 'completed'),
    (select coalesce(sum(amount), 0) from public.transactions
       where type in ('task_reward', 'referral_reward') and status = 'completed'),
    (select coalesce(sum(amount), 0) from public.withdrawals
       where status = 'completed'),
    -- Revenue proxy: fees collected on completed withdrawals. Replace
    -- with your real revenue model once one exists.
    (select coalesce(sum(fee), 0) from public.withdrawals
       where status = 'completed');
end;
$$;

-- ---------------------------------------------------------------------------
-- SUSPENSION ENFORCEMENT — a suspended user can't start new tasks or
-- request withdrawals. Existing balances/history remain visible (their
-- own SELECT policies are untouched), only new actions are blocked.
-- ---------------------------------------------------------------------------
drop policy if exists "Users can start a task" on public.task_submissions;
create policy "Users can start a task"
  on public.task_submissions for insert
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles
      where id = auth.uid() and is_suspended = true
    )
  );

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
begin
  select is_suspended into v_suspended
  from public.profiles where id = auth.uid();

  if v_suspended then
    raise exception 'Account is suspended';
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
-- Make yourself an admin (run once, with your own account's email):
-- ---------------------------------------------------------------------------
-- update public.profiles set is_admin = true
-- where id = (select id from auth.users where email = 'you@example.com');


-- ---------------------------------------------------------------------------
-- TASK REVIEW SETTLEMENT
-- These functions are defined in schema.sql too; keeping the definitions here
-- makes rerunning admin_migration.sql sufficient after an older deployment.
-- ---------------------------------------------------------------------------
create or replace function public.approve_task_submission(p_submission_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare v_submission public.task_submissions%rowtype;
begin
  if not public.is_admin() then raise exception 'Not authorized'; end if;
  select * into v_submission from public.task_submissions where id=p_submission_id for update;
  if not found or v_submission.status <> 'under_review' then raise exception 'Submission is not awaiting review'; end if;
  update public.task_submissions set status='completed', reviewed_at=now() where id=p_submission_id;
  update public.transactions set status='completed'
    where reference_table='task_submissions' and reference_id=p_submission_id
      and type='task_reward' and status='pending';
  update public.user_trust_profiles
    set total_completed_tasks=total_completed_tasks+1, updated_at=now()
    where user_id=v_submission.user_id;
  return 'approved';
end; $$;

create or replace function public.reject_task_submission(p_submission_id uuid, p_reason text default 'Proof did not meet the campaign criteria')
returns text language plpgsql security definer set search_path=public as $$
declare v_submission public.task_submissions%rowtype; v_task public.tasks%rowtype; v_tx public.transactions%rowtype;
begin
  if not public.is_admin() then raise exception 'Not authorized'; end if;
  select * into v_submission from public.task_submissions where id=p_submission_id for update;
  if not found or v_submission.status <> 'under_review' then raise exception 'Submission is not awaiting review'; end if;
  select * into v_task from public.tasks where id=v_submission.task_id;
  update public.task_submissions set status='rejected', rejection_reason=p_reason, reviewed_at=now() where id=p_submission_id;
  select * into v_tx from public.transactions
    where reference_table='task_submissions' and reference_id=p_submission_id
      and type='task_reward' and status='pending' for update;
  if found then
    update public.transactions set status='reversed' where id=v_tx.id;
    update public.campaign_escrow
      set escrow_remaining=escrow_remaining+v_tx.amount
      where campaign_id=v_task.id;
  end if;
  update public.user_trust_profiles
    set total_rejected_tasks=total_rejected_tasks+1, updated_at=now()
    where user_id=v_submission.user_id;
  return 'rejected';
end; $$;

revoke execute on function public.approve_task_submission(uuid) from public, anon;
revoke execute on function public.reject_task_submission(uuid, text) from public, anon;

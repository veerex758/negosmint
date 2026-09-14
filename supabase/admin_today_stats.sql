-- ============================================================================
-- NegosMint admin Today stats + growth charts (run this AFTER schema.sql,
-- admin_migration.sql, rate_limiting.sql, and leveling.sql)
--
-- Extends admin_analytics() with today's figures (new users, tasks
-- completed, pending withdrawals, revenue) and adds admin_growth_series()
-- for the Overview tab's 7-day charts.
-- ============================================================================

create or replace function public.admin_analytics()
returns table (
  total_users bigint,
  active_users bigint,
  tasks_completed bigint,
  total_rewards numeric,
  total_withdrawals numeric,
  revenue numeric,
  new_users_today bigint,
  tasks_completed_today bigint,
  pending_withdrawals bigint,
  revenue_today numeric
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
    (select coalesce(sum(fee), 0) from public.withdrawals
       where status = 'completed'),
    (select count(*) from public.profiles
       where created_at >= current_date),
    (select count(*) from public.task_submissions
       where status = 'completed' and reviewed_at >= current_date),
    (select count(*) from public.withdrawals where status = 'pending'),
    (select coalesce(sum(fee), 0) from public.withdrawals
       where status = 'completed' and created_at >= current_date);
end;
$$;

-- ---------------------------------------------------------------------------
-- admin_growth_series(): one row per day for the last 7 days (including
-- today), always 7 rows even for days with zero activity — generate_series
-- fills the gaps so the chart doesn't silently skip quiet days.
-- ---------------------------------------------------------------------------
create or replace function public.admin_growth_series()
returns table (
  day date,
  new_users bigint,
  tasks_completed bigint,
  withdrawal_volume numeric
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
    d::date as day,
    (select count(*) from public.profiles
       where created_at::date = d::date) as new_users,
    (select count(*) from public.task_submissions
       where status = 'completed' and reviewed_at::date = d::date) as tasks_completed,
    (select coalesce(sum(amount), 0) from public.withdrawals
       where created_at::date = d::date) as withdrawal_volume
  from generate_series(current_date - 6, current_date, interval '1 day') as d
  order by day;
end;
$$;

-- ============================================================================
-- NegosMint leveling (run this AFTER schema.sql, admin_migration.sql, and
-- rate_limiting.sql)
--
-- The `levels` table has existed since schema.sql (created for every user
-- by handle_new_user()), but nothing has ever written to it — every
-- account has sat at level 1, 0 XP. This wires it up: completing a task
-- now earns XP (10 XP per $1 rewarded), and a level-up sends a
-- notification. Replaces complete_task() once more, same body as
-- rate_limiting.sql plus the XP award.
-- ============================================================================

-- ============================================================================
-- NegosMint leveling + streaks (run this AFTER schema.sql,
-- admin_migration.sql, and rate_limiting.sql)
--
-- Two tables have existed since schema.sql but nothing has ever written
-- to them — every account has sat at level 1 / 0 XP, and every streak at
-- 0. This wires up both: completing a task earns XP (10 per $1 rewarded)
-- and advances today's streak (once per day — repeat completions on the
-- same day don't inflate it), with notifications for a level-up or a
-- maintained streak. Replaces complete_task() once more, same body as
-- rate_limiting.sql plus these two.
-- ============================================================================

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
  v_xp_gain integer;
  v_old_level integer;
  v_new_xp integer;
  v_new_level integer;
  v_last_activity date;
  v_new_streak integer;
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

  -- XP: 10 per dollar rewarded. Level: every 100 XP. Both numbers are
  -- easy to retune later — nothing else in the app hardcodes them
  -- except the progress bar math in ProfileScreen, which reads xp/level
  -- back from this table rather than recomputing its own copy.
  v_xp_gain := floor(v_task.reward * 10)::integer;

  select level into v_old_level from public.levels where user_id = auth.uid();

  update public.levels
  set xp = xp + v_xp_gain,
      level = ((xp + v_xp_gain) / 100) + 1,
      updated_at = now()
  where user_id = auth.uid()
  returning xp, level into v_new_xp, v_new_level;

  if v_new_level > coalesce(v_old_level, 1) then
    insert into public.notifications (user_id, type, title, body)
    values (
      auth.uid(), 'level_up', 'Level Up!',
      'You reached Level ' || v_new_level || '.'
    );
  end if;

  -- Streak: same calendar day as last activity → no change (don't let
  -- someone inflate it by completing 20 tasks in one sitting). Exactly
  -- one day after → +1. Any bigger gap (or first-ever completion) →
  -- resets to 1, since the streak was broken.
  select last_activity_date into v_last_activity
  from public.streaks where user_id = auth.uid();

  if v_last_activity is null or v_last_activity < current_date - 1 then
    v_new_streak := 1;
  elsif v_last_activity = current_date - 1 then
    v_new_streak := (
      select current_streak + 1 from public.streaks where user_id = auth.uid()
    );
  else
    -- v_last_activity = current_date: already counted today.
    v_new_streak := null;
  end if;

  if v_new_streak is not null then
    update public.streaks
    set current_streak = v_new_streak,
        last_activity_date = current_date,
        updated_at = now()
    where user_id = auth.uid();

    insert into public.notifications (user_id, type, title, body)
    values (
      auth.uid(), 'streak_maintained', 'Streak Maintained',
      'You''ve earned a ' || v_new_streak || '-day streak!'
    );
  end if;
end;
$$;

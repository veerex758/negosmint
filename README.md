# NegosMint (Flutter)

**Earn. Achieve. Advance.**

Implemented in Flutter/Dart with the Midnight Cobalt identity — no neon
green anywhere. Covers the full original build plan except deposits (see
"Not included" below).

## What's included

- **Theme** (`lib/core/theme`) — full Midnight Cobalt color system + dark
  `ThemeData` (Inter via Google Fonts).
- **Reusable widgets** (`lib/core/widgets`):
  - `GlassCard` — glassmorphism panel with entrance (fade+slide+scale) and
    tap animation.
  - `PrimaryButton` — brand-gradient button with tap scale/glow and loading
    state.
  - `AnimatedCoin` — chrome/cobalt rotating NM coin.
  - `ParticleBackground` — obsidian gradient + soft glow blobs + drifting
    dots (stand-in for the world map, no image assets needed).
  - `AnimatedCounter` — smooth balance counting instead of instant jumps.
  - `TaskCard` — shared task-list item; tapping it opens Task Details
    rather than starting the task immediately.
- **Screens**: Splash, Login, Register, Dashboard (streak, balance, quick
  actions, real earnings chart, recommended tasks), Tasks (category
  filters), **Task Details** (reward/time/difficulty/requirements/steps
  before committing), Wallet (breakdown + transaction history), Withdraw
  (amount → method → summary → confirm), Referrals (code, stats, real
  share sheet), Notifications, Profile (stats, Level/XP progress bar,
  settings menu), Admin Dashboard (analytics, withdrawal approve/reject,
  task management, user suspend), and a glass bottom-nav shell tying the
  main five together.

## Backend setup (Supabase)

1. Create a project at supabase.com.
2. Open the SQL editor and run `supabase/schema.sql` top to bottom. It
   creates every table, the wallet ledger view, RLS policies, and the
   `complete_task()` / `request_withdrawal()` functions that do
   server-side reward validation (see comments in that file for why).
3. Run `supabase/admin_migration.sql` next (same SQL editor, new query).
   It adds everything the admin dashboard needs — suspension support,
   admin RLS policies, and the approve/reject-withdrawal functions.
4. Run `supabase/rate_limiting.sql` next. It layers rate limits onto
   `complete_task()` and `request_withdrawal()` (max 20 task completions/
   hour, one pending withdrawal at a time, 5 withdrawals/24h, $5 minimum
   withdrawal) and adds a `fraud_flags` table that gets a row if 5+
   signups credit the same referral code within an hour — a signal for
   an admin to review, not an automatic block, since that pattern also
   happens organically (e.g. a shared wifi network).
5. Run `supabase/leveling.sql` next. Both the `levels` and `streaks`
   tables have existed since schema.sql but nothing ever wrote to
   them — this wires up XP (10 per $1 earned), levels, daily streaks,
   and their notifications on task completion.
6. Run `supabase/admin_today_stats.sql` next. Adds today's figures
   (new users, tasks completed, pending withdrawals, revenue) and a
   7-day series for the Overview tab's growth charts.
7. Make your own account an admin: sign up in the app first (so your
   `profiles` row exists), then in the SQL editor run:

   ```sql
   update public.profiles set is_admin = true
   where id = (select id from auth.users where email = 'you@example.com');
   ```

   Log out and back in — you'll see **Admin Dashboard** at the bottom of
   the Profile screen's menu.
8. Grab your project's URL and anon key from Project Settings → API.
9. Run locally with both passed in:

   ```bash
   flutter pub get
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
   ```

10. For CI, add `SUPABASE_URL` and `SUPABASE_ANON_KEY` as repo secrets
   (Settings → Secrets and variables → Actions) — `build-apk.yml` already
   passes them through to the release build.

Without these, the app still boots (splash/login/register UI all work)
but sign-in and sign-up will show an auth error, since there's no backend
to talk to yet.

## Not included yet (per the original phased plan)

- Settings sub-pages (Edit Profile, Security, Language, Help, Terms,
  Privacy are all placeholder menu items — the Level/XP piece they used
  to lack is now built).
- Deposits (button shows a message rather than a real flow — there's no
  payment provider integration yet, and picking one — Stripe, Paystack,
  Flutterwave, etc. — is a decision only you can make).

Everything else — sign up, sign in, browsing tasks, task details,
starting/completing tasks, wallet balance and history, withdrawals,
referral code/stats/sharing, notifications, profile stats and Level/XP,
logout, the dashboard's weekly change %, the earnings chart's
7D/1M/3M/1Y series, the admin dashboard (analytics, withdrawal
approve/reject, task create/disable, user suspend), and rate limiting
(task-completion speed cap, withdrawal frequency/minimum, referral-
velocity flagging), and Level/XP/streaks — is wired to Supabase for real
once you've run all five SQL files and set your credentials.

## Structure

```
lib/
├── main.dart
├── core/{theme,widgets,config}
├── models/          # AppProfile, WalletTransaction, TaskModel,
│                     # AdminAnalytics, AdminWithdrawal, AdminUserRow,
│                     # AdminGrowthPoint, etc.
├── services/         # AuthService, WalletService, TaskService,
│                     # NotificationService, ReferralService, AdminService
└── screens/{splash,auth,dashboard,tasks,wallet,referral,profile,
             main_nav,notifications,admin}
supabase/
├── schema.sql            # run first
├── admin_migration.sql   # run second
├── rate_limiting.sql     # run third
├── leveling.sql          # run fourth (XP, levels, streaks)
└── admin_today_stats.sql # run fifth (Today stats + growth charts)
```

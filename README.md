# NegosMint (Flutter)

**Cobalt. Precision. Motion.**

This is Phase 1–3 of the NegosMint build plan (Foundation + UI + Core screens),
implemented in Flutter/Dart with the Midnight Cobalt identity — no neon green
anywhere.

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
  - `TaskCard` — shared task-list item.
- **Screens**: Splash (logo fade/scale/glow → auto-navigates), Login,
  Register (with success check animation), Dashboard (streak, balance,
  quick actions, earnings mini-chart, available tasks), Tasks (category
  filters), Wallet (breakdown + transaction history), Referrals (code +
  stats), Profile (stats + settings menu), and a glass bottom-nav shell
  tying them together.

All data on these screens is local placeholder state — there is no backend
yet (see "Not included" below).

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
   hour, one pending withdrawal at a time, 5 withdrawals/24h) and adds a
   `fraud_flags` table that gets a row if 5+ signups credit the same
   referral code within an hour — a signal for an admin to review, not
   an automatic block, since that pattern also happens organically (e.g.
   a shared wifi network).
5. Make your own account an admin: sign up in the app first (so your
   `profiles` row exists), then in the SQL editor run:

   ```sql
   update public.profiles set is_admin = true
   where id = (select id from auth.users where email = 'you@example.com');
   ```

   Log out and back in — you'll see **Admin Dashboard** at the bottom of
   the Profile screen's menu.
6. Grab your project's URL and anon key from Project Settings → API.
7. Run locally with both passed in:

   ```bash
   flutter pub get
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
   ```

8. For CI, add `SUPABASE_URL` and `SUPABASE_ANON_KEY` as repo secrets
   (Settings → Secrets and variables → Actions) — `build-apk.yml` already
   passes them through to the release build.

Without these, the app still boots (splash/login/register UI all work)
but sign-in and sign-up will show an auth error, since there's no backend
to talk to yet.

## Not included yet (per the original phased plan)

- Settings sub-pages and the level/XP UI.
- Deposits (button shows a "coming soon" message — there's no deposit
  flow or payment provider integration yet, and picking one — Stripe,
  Paystack, Flutterwave, etc. — is a decision only you can make).

Everything else — sign up, sign in, browsing/starting/completing tasks,
wallet balance and history, withdrawals, referral code/stats/sharing,
notifications, profile stats, logout, the dashboard's weekly change %,
the earnings chart's 7D/1M/3M/1Y series, the admin dashboard (analytics,
withdrawal approve/reject, task create/disable, user suspend), and
rate limiting (task-completion speed cap, withdrawal frequency cap,
referral-velocity flagging) — is wired to Supabase for real once you've
run all three SQL files and set your credentials.

## Structure

```
lib/
├── main.dart
├── core/{theme,widgets,config}
├── models/          # AppProfile, WalletTransaction, TaskModel
├── services/         # AuthService, WalletService, TaskService
└── screens/{splash,auth,dashboard,tasks,wallet,referral,profile,main_nav,notifications}
supabase/
└── schema.sql        # run this in the Supabase SQL editor
```

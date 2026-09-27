# NegosMint (Flutter)

**Complete. Earn. Grow.**

Implemented in Flutter/Dart with the vault-green NegosMint identity. The
updated earning flow reserves campaign inventory, collects proof, and sends
it through a server-owned verification and escrow path rather than crediting
rewards from the client.

## What's included

- **Theme** (`lib/core/theme`) — vault-green, sage, and sage-gold system + dark
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
   `reserve_task_slot()` / `submit_task_proof()` / `request_withdrawal()` functions that do
   server-side slot reservation, proof verification routing, escrow, and reward validation.
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
7. Run `supabase/deposits.sql` next. Adds the `deposits` table and the
   service-role-only `credit_deposit()` / `mark_deposit_failed()`
   functions the Stripe Edge Functions call (see "Deposits" below —
   this table has no client-facing write policy at all, by design).
8. Make your own account an admin: sign up in the app first (so your
   `profiles` row exists), then in the SQL editor run:

   ```sql
   update public.profiles set is_admin = true
   where id = (select id from auth.users where email = 'you@example.com');
   ```

   Log out and back in — you'll see **Admin Dashboard** at the bottom of
   the Profile screen's menu.
9. Grab your project's URL and anon key from Project Settings → API.
10. Run locally with both passed in (add `STRIPE_PUBLISHABLE_KEY` too
    once you've done the Stripe setup below):

    ```bash
    flutter pub get
    flutter run \
      --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
      --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi... \
      --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
    ```

11. For CI, add `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
    `STRIPE_PUBLISHABLE_KEY` as repo secrets (Settings → Secrets and
    variables → Actions) — `build-apk.yml` already passes all three
    through to the release build.

Without these, the app still boots (splash/login/register UI all work)
but sign-in and sign-up will show an auth error, since there's no backend
to talk to yet.

## Deposits (Stripe)

Deposits are the one feature that needed genuinely different
infrastructure from everything else in this app: real server-side
TypeScript functions (Deno, via Supabase Edge Functions) that call out
to Stripe, not just Postgres. `supabase/functions/README.md` is worth
reading in full, but the short version:

1. **Get your Stripe keys.** Dashboard → Developers → API keys. You'll
   need the **secret key** (`sk_...`) for the Edge Functions and the
   **publishable key** (`pk_...`) for the Flutter app. Use test-mode
   keys until you're ready to go live.
2. **Install the Supabase CLI** and link your project:
   ```bash
   npm install -g supabase
   supabase login
   supabase link --project-ref your-project-ref
   ```
3. **Set the Edge Function secrets** (these never go in the Flutter app
   or in git — only here):
   ```bash
   supabase secrets set STRIPE_SECRET_KEY=sk_test_...
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
   ```
   (You'll get the webhook secret in step 5 below — come back and set
   it after.)
4. **Deploy the three functions:**
   ```bash
   supabase functions deploy create-payment-intent
   supabase functions deploy stripe-webhook --no-verify-jwt
   ```
   The `--no-verify-jwt` on the webhook matters — Stripe calls that URL
   directly and has no Supabase session to send. Its authenticity check
   is the Stripe signature, not a Supabase JWT.
5. **Add the webhook in Stripe.** Dashboard → Developers → Webhooks →
   Add endpoint. URL is
   `https://<project-ref>.supabase.co/functions/v1/stripe-webhook`.
   Listen for `payment_intent.succeeded` and
   `payment_intent.payment_failed`. Copy the signing secret it gives you
   and run the `STRIPE_WEBHOOK_SECRET` command from step 3.
6. **Required native Android setup.** `flutter_stripe` needs a few
   changes to `android/` that I don't have access to generate myself
   (I've only ever touched `lib/`, `pubspec.yaml`, and `supabase/` in
   this project) — without these, the payment sheet will crash on
   Android, or the release build will fail outright:
   - In `android/app/build.gradle`, under `defaultConfig`, set
     `minSdkVersion 21` (or higher).
   - In `android/app/src/main/kotlin/.../MainActivity.kt`, change the
     class to extend `FlutterFragmentActivity` instead of
     `FlutterActivity`:
     ```kotlin
     import io.flutter.embedding.android.FlutterFragmentActivity
     class MainActivity: FlutterFragmentActivity()
     ```
   - In `android/app/src/main/res/values/styles.xml` **and**
     `values-night/styles.xml`, make sure your theme's `parent` derives
     from `Theme.AppCompat.*` or `Theme.MaterialComponents.*` (not
     `Theme.Light.NoTitleBar` or similar).
   - **Required, not optional:** `flutter_stripe` transitively depends
     on `com.stripe:stripe-android-issuing-push-provisioning`, which in
     turn needs `com.google.android.gms:play-services-tapandpay` — a
     Google artifact that's invite-only and won't resolve from public
     Maven repos for most accounts. This is a known, currently
     unresolved upstream issue
     ([flutter_stripe#2252](https://github.com/flutter-stripe/flutter_stripe/issues/2252)),
     not something specific to this project. Push provisioning (adding
     a card directly to the Google Pay wallet from inside the app) is a
     separate feature from accepting payments and isn't used here, so
     the fix is to tell Gradle not to resolve it at all. In the
     **project-level** `android/build.gradle` (the one at `android/`,
     not `android/app/`), add inside (or alongside) the existing
     `allprojects` block:
     ```gradle
     allprojects {
         configurations.all {
             exclude group: 'com.google.android.gms', module: 'play-services-tapandpay'
         }
     }
     ```
   - In `android/app/proguard-rules.pro`, add:
     ```
     -dontwarn com.stripe.android.pushProvisioning.**
     -dontwarn com.google.android.gms.tapandpay.**
     -dontwarn kotlinx.parcelize.Parceler$DefaultImpls
     -dontwarn kotlinx.parcelize.Parceler
     -dontwarn kotlinx.parcelize.Parcelize
     -keep class com.stripe.** { *; }
     ```
     These matter even if `minifyEnabled` looks like it's off somewhere
     — several build variants enable it independently, and the lint/R8
     tasks that hit this exact failure run during a normal
     `flutter build apk --release`.
   - After any of the above, run a full clean rebuild — hot reload/hot
     restart won't pick up native Gradle changes:
     ```bash
     flutter clean
     cd android && ./gradlew clean && cd ..
     flutter pub get
     ```

**What's covered by "all methods":** the PaymentIntent is created with
`automatic_payment_methods: { enabled: true }`, so Stripe's payment
sheet shows whatever's enabled in your Dashboard (Settings → Payment
methods) — cards plus whatever else makes sense for USD. **Apple Pay
and Google Pay specifically need additional native setup** (an Apple
Merchant ID + entitlement, a Google Pay config) that's outside what I
can configure without Xcode/native Android project access — see
[flutter_stripe's Apple Pay](https://docs.page/flutter-stripe/flutter_stripe/applepay)
and [Google Pay](https://docs.page/flutter-stripe/flutter_stripe/googlepay)
guides if you want those specifically.

**Why two confirmation paths?** `confirm-deposit` is the fast path —
called the instant the payment sheet closes, and gives the user
immediate feedback. `stripe-webhook` is the safety net for when that
call never happens (app killed, connection dropped right after paying).
`credit_deposit()` is idempotent, so whichever one gets there first
does the work and the other is a no-op.

## Not included yet (per the original phased plan)

- Settings sub-pages (Edit Profile, Security, Language, Help, Terms,
  Privacy are all placeholder menu items).

Everything else — sign up, sign in, browsing tasks, task details,
slot reservation and proof submission, wallet balance and history, deposits (Stripe),
withdrawals, referral code/stats/sharing, notifications, profile stats
and Level/XP, logout, the dashboard's weekly change %, the earnings
chart's 7D/1M/3M/1Y series, the admin dashboard (analytics, withdrawal
approve/reject, task create/disable, user suspend), and rate limiting
(task-completion speed cap, withdrawal frequency/minimum, referral-
velocity flagging) — is wired to Supabase (and Stripe) for real once
you've run all six SQL files, deployed the three Edge Functions, and set
your credentials.

## Structure

```
lib/
├── main.dart
├── core/{theme,widgets,config}
├── models/          # AppProfile, WalletTransaction, TaskModel,
│                     # AdminAnalytics, AdminWithdrawal, AdminUserRow,
│                     # AdminGrowthPoint, etc.
├── services/         # AuthService, WalletService, TaskService,
│                     # NotificationService, ReferralService,
│                     # AdminService, DepositService
└── screens/{splash,auth,dashboard,tasks,wallet,referral,profile,
             main_nav,notifications,admin}
supabase/
├── schema.sql            # run 1st
├── admin_migration.sql   # run 2nd
├── rate_limiting.sql     # run 3rd
├── leveling.sql          # run 4th (XP, levels, streaks)
├── admin_today_stats.sql # run 5th (Today stats + growth charts)
├── deposits.sql          # run 6th (deposits table + credit function)
└── functions/            # deploy via Supabase CLI, see "Deposits" above
    ├── create-payment-intent/
    ├── stripe-webhook/
    └── _shared/cors.ts
```

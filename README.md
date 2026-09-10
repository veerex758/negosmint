# # NegosMint (Flutter)

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

## Run it

```bash
flutter pub get
flutter run
```

Requires the Flutter SDK (stable channel) — this environment couldn't run
`flutter pub get` itself (no network access), so dependency resolution and
device testing need to happen on your machine.

## Not included yet (per the original phased plan)

These are Phase 4–8 in the original plan and are substantial projects of
their own — happy to build them next, one phase at a time:

- Task-completion success animation (checkmark draw + coin burst), withdrawal
  flow (amount entry → method → summary → confirmation), notifications
  screen, level/XP system, settings sub-pages.
- **Backend**: auth, database, task verification, and a real transaction
  ledger (wallet balances must never live only on-device).
- **Anti-fraud & security**: server-side reward validation, rate limiting,
  fraud detection.
- **Admin dashboard**: separate app/panel for managing users, tasks, and
  withdrawals.

## Structure

```
lib/
├── main.dart
├── core/{theme,widgets}
└── screens/{splash,auth,dashboard,tasks,wallet,referral,profile,main_nav}
```

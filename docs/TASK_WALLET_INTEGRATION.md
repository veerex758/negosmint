# NegosMint Task App ↔ Wallet Integration

## Status

The integration is being built in stages. The current pull request defines the safe architecture and adds a server-side challenge verifier, but the wallet signing UI and task-app callback are not yet wired to it. Do not treat the integration as complete.

Repositories:
- Task/rewards app: `veerex758/negosmint`
- Self-custody wallet: `veerex758/Negosmint-`

## What exists today

### Task/rewards app
- Supabase Auth identifies the task-app user.
- `WalletService` reads the `wallet_balances` view, derived from the transactions ledger.
- Task rewards and withdrawals are server-side ledger operations; the client must never write its own balance.
- A crypto-withdrawal migration defines balances for USDT/USDC and networks Ethereum, BSC, Polygon, Arbitrum, and Base, with withdrawal requests and settlement fields.

### NegosMint Wallet
- The wallet is non-custodial: seed phrases, private keys, PINs, and decrypted signing material stay on the device.
- The current wallet `pubspec.yaml` does not include `supabase_flutter`, and `lib/app.dart` starts at the splash screen; there is no existing Supabase auth/session integration in the wallet app.
- Its documented V1 network is Ethereum Sepolia (chain ID 11155111), with native ETH support and transfer foundations.
- Its connection layer supports wallet-connection requests, but pairing/connection is not the same as proving ownership of a task-app account or enabling a funded withdrawal.

## Existing connection flow: security gap found

The task app already has `wallet_connections` metadata and a `WalletConnectionService`. However, the current database migration grants authenticated users direct INSERT and UPDATE access to their own connection row, including `wallet_address`, `chain_id`, `network`, and `session_id`. The client checks that the callback says `approved`, matches a request ID, and has correctly shaped fields, but those checks alone do not cryptographically prove that the user controls the supplied address. A modified client can fabricate those fields.

**Do not treat the existing row as a verified wallet identity or as sufficient authorization for payouts.** Verified ownership is stored separately in `verified_wallet_addresses`; the client has SELECT-only access to that table and cannot create or change verified records.

## Server-side challenge verifier added

The task-app branch now includes:
- `supabase/migrations/20261009_wallet_link_verification.sql`: challenge records, a separate verified-address table, RLS, and a service-role-only atomic challenge-consumption function.
- `supabase/functions/verify-wallet-link/index.ts`: authenticated `create_challenge` and `verify_signature` actions. Challenges are bound to the signed-in user, exact message, Sepolia chain ID, random nonce, and five-minute expiry. Ethers verifies the signature; a database function atomically consumes the challenge and writes the verified address, preventing replay.

**This is backend foundation, not end-to-end completion.** The wallet app still needs an explicit review screen and local message-signing action, and the task app still needs to submit the signature to this endpoint and display the verified address. The migration and Edge Function have not yet been deployed to Supabase or verified against the production project. Deploy only after confirming the intended Supabase project and reviewing the diff.

## Callback transport mismatch found

The current Task App constructs a custom-scheme callback (`negosmint://wallet/callback`), but the wallet's request model and callback transport accept HTTPS callbacks only. Therefore the current callback contract is inconsistent and must be corrected before the two apps can complete the verification handshake. The safe planned flow is for the wallet to POST the approved signed challenge to the Task App's HTTPS Edge Function callback; the Task App then reads the resulting verified address from Supabase. Do not put signatures in URL query parameters, and do not accept an unverified deep-link result as proof of ownership.

## Important compatibility gap

The task app's crypto-withdrawal schema describes USDT/USDC on several networks, while the wallet's documented V1 is Sepolia native ETH. These are not interchangeable. Do not present a withdrawal as supported, broadcast a payment, or mark it completed until the chosen asset/network is actually supported and a real settlement path is configured and tested.

A database balance is an application ledger entry, not cryptocurrency held on-chain. Crediting a crypto balance requires a verified funding source or a properly designed payout/settlement process.

## Integration rules

1. **Keep the ledger authoritative.** Approved task rewards remain in the task app's server-side ledger. Never let the wallet app or client set an earnings balance.
2. **Link only public wallet data.** The wallet address may be shared after explicit user approval. Never send a seed phrase, private key, PIN, or decrypted key material to Supabase or the task app.
3. **Prove address ownership before withdrawals.** A pasted address is not proof that the user controls it. Use a short-lived, one-time server challenge signed locally in the wallet and verified server-side. Bind it to the authenticated user, chain, expiry, and nonce, and prevent replay.
4. **Separate linking from spending.** Linking a public address must not trigger a transaction, sign a transfer, or automatically approve a withdrawal. Every withdrawal needs a clear confirmation and a server-side balance check.
5. **Use explicit network and asset checks.** Reject unsupported chain IDs/assets rather than silently switching networks or treating testnet funds as real value.
6. **Make settlement auditable and idempotent.** Only a trusted server-side settlement process may finalize a withdrawal, with a verified transaction hash, correct chain, recipient, asset, and amount. Repeated callbacks must not double-debit or double-complete a withdrawal.
7. **Test before release.** Cover unauthenticated access, another user's address/challenge, expired and replayed challenges, malformed addresses, unsupported networks, insufficient balance, duplicate settlement, failed transfers, and rollback/refund behavior.

## Delivery sequence

- [ ] Confirm the two apps' intended production environment and Supabase project identity. The task app uses build-time `SUPABASE_URL` / `SUPABASE_ANON_KEY`; the wallet currently has no Supabase configuration or auth client. Do not assume they share a project or auth session.
- [x] Audit the existing client-writable connection metadata and separate it from verified ownership.
- [x] Add the initial server-side address/challenge schema and signature-verification endpoint on the integration branch.
- [ ] Add wallet-side explicit approval and local signing of the exact server challenge; never expose key material.
- [ ] Align the callback contract: use the authenticated Task App to create the challenge, then an HTTPS callback to submit the signature; do not rely on the current custom-scheme callback.
- [ ] Replace task-app direct connection writes with the authenticated Edge Function flow and render the verified address.
- [ ] Add tests for invalid, expired, mismatched, and replayed signatures/challenges; run Edge Function type checks and Flutter CI.
- [ ] Deploy the migration and function to the confirmed Supabase project only after review.
- [ ] Separately implement and audit funded withdrawal settlement for one supported asset/network.
- [ ] Run end-to-end testnet tests before enabling any withdrawal UI.

## Release gate

Until the compatibility gap and settlement path are resolved, treat crypto withdrawals as **not production-ready**. Do not advertise an in-app task balance as on-chain funds, and do not enable mainnet payouts from the current Sepolia-only wallet.

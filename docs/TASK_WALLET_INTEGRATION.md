# NegosMint Task App ↔ Wallet Integration

## Status

This document records the verified starting point and the safe integration sequence. It is not a claim that the two apps are already connected.

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
- Its documented V1 network is Ethereum Sepolia (chain ID 11155111), with native ETH support and transfer foundations.
- Its connection layer supports wallet-connection requests, but pairing/connection is not the same as proving ownership of a task-app account or enabling a funded withdrawal.

## Important compatibility gap

The task app's crypto-withdrawal schema describes USDT/USDC on several networks, while the wallet's documented V1 is Sepolia native ETH. These are not interchangeable. Do not present a withdrawal as supported, broadcast a payment, or mark it completed until the chosen asset/network is actually supported and a real settlement path is configured and tested.

A database balance is an application ledger entry, not cryptocurrency held on-chain. Crediting a crypto balance requires a verified funding source or a properly designed payout/settlement process.

## Integration rules

1. **Keep the ledger authoritative.** Approved task rewards remain in the task app's server-side ledger. Never let the wallet app or client set an earnings balance.
2. **Link only public wallet data.** The wallet address may be shared after explicit user approval. Never send a seed phrase, private key, PIN, or decrypted key material to Supabase or the task app.
3. **Prove address ownership before withdrawals.** A pasted address is not proof that the user controls it. Add a short-lived, one-time server challenge and have the wallet sign it locally; verify the signature server-side before marking an address as verified. Bind the challenge to the authenticated user, chain, expiry, and nonce, and prevent replay.
4. **Separate linking from spending.** Linking a public address must not trigger a transaction, sign a transfer, or automatically approve a withdrawal. Every withdrawal needs a clear confirmation and a server-side balance check.
5. **Use explicit network and asset checks.** Reject unsupported chain IDs/assets rather than silently switching networks or treating testnet funds as real value.
6. **Make settlement auditable and idempotent.** Only a trusted server-side settlement process may finalize a withdrawal, with a verified transaction hash, correct chain, recipient, asset, and amount. Repeated callbacks must not double-debit or double-complete a withdrawal.
7. **Test before release.** Cover unauthenticated access, another user's address/challenge, expired and replayed challenges, malformed addresses, unsupported networks, insufficient balance, duplicate settlement, failed transfers, and rollback/refund behavior.

## Delivery sequence

- [ ] Confirm the two apps' intended production environment and Supabase project identity; do not assume they share a project or auth session.
- [ ] Choose the first supported integration target. The lowest-risk initial milestone is linking and displaying a verified public address, without enabling withdrawals.
- [ ] Add the server-side address/challenge schema and signature-verification endpoint.
- [ ] Add wallet-side explicit approval and local signing of the challenge only; never expose key material.
- [ ] Show verified address and supported chain in the task app.
- [ ] Separately implement and audit funded withdrawal settlement for one supported asset/network.
- [ ] Run CI, database migration checks, and end-to-end testnet tests before enabling any withdrawal UI.

## Release gate

Until the compatibility gap and settlement path are resolved, treat crypto withdrawals as **not production-ready**. Do not advertise an in-app task balance as on-chain funds, and do not enable mainnet payouts from the current Sepolia-only wallet.

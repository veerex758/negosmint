# Secure Task App ↔ Wallet ownership handoff

Status: design contract only. Do not enable withdrawals or treat legacy `wallet_connections` rows as ownership proof.

## Threat model and non-negotiable rules

- The Task App's authenticated Supabase session stays inside the Task App. Never pass its access/refresh token to the Wallet App.
- The Wallet App is non-custodial: mnemonic, private key, PIN, biometric result and decrypted key material never leave the device or enter logs.
- A wallet link is valid only after the Task App's authenticated `verify-wallet-link` function verifies the exact message signature and atomically consumes the short-lived challenge.
- A custom URI, callback URL, request ID, wallet address, or legacy session is not proof of ownership.
- Never put a signature in a URL/query string, clipboard, analytics, or log. Do not let the client write `verified_wallet_addresses`.
- No transaction is requested or signed in this flow. V1 is Ethereum Sepolia only (chain ID 11155111).

## Required Android handoff

Use an explicit, package-targeted Android activity-result channel, not a browsable custom-scheme callback. The Task App must resolve the installed wallet package and launch its exported activity explicitly; the wallet returns a bounded result through the originating activity result. The result must not be accepted from an unrelated app, a URL, or a stale launch. Add native integration to both Android hosts and expose it to Flutter through a narrowly scoped MethodChannel.

The Wallet App must treat all incoming extras as untrusted. It may accept only a bounded challenge envelope with:
- protocol version;
- challenge UUID;
- exact server-generated message;
- Sepolia chain ID;
- expiry timestamp.

The wallet UI must independently validate the expected NegosMint purpose, challenge ID, chain ID, expiry and no-transaction statement, then show the exact message and require explicit consent plus local biometric/device authentication before signing. Reject invalid, expired, oversized, duplicate, or unsupported requests. Return only challenge ID, public address, chain ID and signature. Never return secrets.

The Task App must verify the returned challenge ID matches the in-memory pending challenge, ensure the user is still signed in as the same account that created it, then submit the signature using its own authenticated Supabase session. The server remains the authority: verify signature, expiry, user binding and one-time consumption. Clear pending state on cancel, timeout, app restart, account switch, or completion.

## End-to-end sequence

1. Signed-in Task App calls `create_challenge` through the authenticated Supabase client.
2. Task App launches the wallet through the explicit Android activity-result channel with the challenge envelope.
3. Wallet displays the exact challenge and explains that no transaction is being authorized.
4. User approves; wallet performs local authentication and signs the exact UTF-8 message bytes locally.
5. Wallet returns the bounded proof result through the activity result; rejection returns no signature.
6. Task App checks the active account and pending challenge, then calls authenticated `verify_signature`.
7. Task App reloads `verified_wallet_addresses` from the server and displays verified status only from that server row.

## Required tests before enabling the feature

- valid approval verifies and displays the server-returned address;
- reject/cancel returns no signature and writes no verified row;
- tampered message, challenge ID, chain ID, address, signature or expiry is rejected;
- expired and already-consumed challenges fail;
- signature result from an old launch is rejected;
- account switch between challenge and result is rejected;
- two users cannot verify against each other's challenge;
- app restart clears in-memory pending state;
- no signature appears in logs, URLs, analytics or server logs;
- legacy `wallet_connections` never grants verified status or payout permission.

## Rollout gate

Do not merge the handoff as production-ready until Android integration tests pass on device, backend migration/function are deployed and verified, and payout authorization independently checks server-verified wallet ownership. Keep withdrawals disabled until settlement, destination, amount, asset, network and confirmation checks are implemented server-side.

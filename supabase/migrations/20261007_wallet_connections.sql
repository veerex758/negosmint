-- Self-custody wallet connection metadata only.
-- Never store private keys, seed phrases, PINs, or decrypted key material here.

create table if not exists public.wallet_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  wallet_address text not null,
  chain_id bigint not null,
  network text not null,
  session_id text not null,
  permissions text[] not null default '{}',
  connected_at timestamptz not null default now(),
  last_used_at timestamptz not null default now(),
  revoked_at timestamptz
);

create unique index if not exists wallet_connections_user_session_idx
  on public.wallet_connections(user_id, session_id);

create unique index if not exists wallet_connections_active_user_idx
  on public.wallet_connections(user_id)
  where revoked_at is null;

alter table public.wallet_connections enable row level security;

drop policy if exists "Users can view their wallet connection" on public.wallet_connections;
create policy "Users can view their wallet connection"
  on public.wallet_connections for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their wallet connection" on public.wallet_connections;
create policy "Users can create their wallet connection"
  on public.wallet_connections for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their wallet connection" on public.wallet_connections;
create policy "Users can update their wallet connection"
  on public.wallet_connections for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.wallet_connections from anon;
grant select, insert, update on public.wallet_connections to authenticated;

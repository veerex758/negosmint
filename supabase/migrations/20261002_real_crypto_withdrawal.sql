create table if not exists public.crypto_wallet_balances (
  user_id uuid not null references public.profiles(id) on delete cascade,
  asset text not null,
  network text not null,
  available numeric(30,18) not null default 0 check (available >= 0),
  pending numeric(30,18) not null default 0 check (pending >= 0),
  lifetime_credited numeric(30,18) not null default 0 check (lifetime_credited >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, asset, network)
);

alter table public.withdrawals
  add column if not exists asset text,
  add column if not exists network text,
  add column if not exists wallet_address text,
  add column if not exists tx_hash text,
  add column if not exists chain_id bigint,
  add column if not exists failure_reason text;

create unique index if not exists withdrawals_tx_hash_unique
  on public.withdrawals(tx_hash) where tx_hash is not null;

alter table public.crypto_wallet_balances enable row level security;

drop policy if exists "users can view own crypto balances" on public.crypto_wallet_balances;
create policy "users can view own crypto balances"
  on public.crypto_wallet_balances for select using (auth.uid() = user_id);

create or replace function public.request_crypto_withdrawal(
  p_amount numeric, p_asset text, p_network text, p_wallet_address text
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_withdrawal_id uuid;
  v_balance public.crypto_wallet_balances%rowtype;
begin
  if v_user is null then raise exception 'Not authenticated'; end if;
  if p_amount <= 0 then raise exception 'Amount must be greater than zero'; end if;
  if upper(p_asset) not in ('USDT','USDC') then raise exception 'Unsupported asset'; end if;
  if upper(p_network) not in ('ETHEREUM','BSC','POLYGON','ARBITRUM','BASE') then raise exception 'Unsupported network'; end if;
  if p_wallet_address !~ '^0x[0-9a-fA-F]{40}$' then raise exception 'Invalid EVM wallet address'; end if;

  select * into v_balance from public.crypto_wallet_balances
  where user_id = v_user and asset = upper(p_asset) and network = upper(p_network) for update;

  if not found or v_balance.available < p_amount then raise exception 'Insufficient crypto balance'; end if;

  update public.crypto_wallet_balances
  set available = available - p_amount, pending = pending + p_amount, updated_at = now()
  where user_id = v_user and asset = upper(p_asset) and network = upper(p_network);

  insert into public.withdrawals(user_id, amount, fee, method, status, transaction_ref, asset, network, wallet_address)
  values (v_user, p_amount, 0, 'crypto', 'pending', 'CRYPTO-' || gen_random_uuid()::text,
          upper(p_asset), upper(p_network), p_wallet_address)
  returning id into v_withdrawal_id;
  return v_withdrawal_id;
end;
$$;

create or replace function public.release_crypto_withdrawal(p_withdrawal_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v public.withdrawals%rowtype;
begin
  select * into v from public.withdrawals where id = p_withdrawal_id for update;
  if not found then raise exception 'Withdrawal not found'; end if;
  if v.status in ('completed','rejected') then return; end if;
  update public.crypto_wallet_balances
  set available = available + v.amount, pending = greatest(0, pending - v.amount), updated_at = now()
  where user_id = v.user_id and asset = v.asset and network = v.network;
  update public.withdrawals set status = 'rejected', failure_reason = left(p_reason,500) where id = p_withdrawal_id;
end;
$$;

create or replace function public.complete_crypto_withdrawal(p_withdrawal_id uuid, p_tx_hash text, p_chain_id bigint)
returns void language plpgsql security definer set search_path = public as $$
declare v public.withdrawals%rowtype;
begin
  select * into v from public.withdrawals where id = p_withdrawal_id for update;
  if not found then raise exception 'Withdrawal not found'; end if;
  if v.status = 'completed' then return; end if;
  if v.status = 'rejected' then raise exception 'Withdrawal already rejected'; end if;

  update public.crypto_wallet_balances
  set pending = greatest(0, pending - v.amount), updated_at = now()
  where user_id = v.user_id and asset = v.asset and network = v.network;

  update public.withdrawals
  set status = 'completed', tx_hash = p_tx_hash, transaction_ref = p_tx_hash, chain_id = p_chain_id
  where id = p_withdrawal_id;

  insert into public.transactions(user_id,type,status,amount,description,reference_table,reference_id)
  values (v.user_id,'withdrawal','completed',-v.amount,
          'Crypto withdrawal ' || v.asset || ' on ' || v.network,'withdrawals',v.id);
end;
$$;

revoke all on function public.request_crypto_withdrawal(numeric,text,text,text) from public, anon;
grant execute on function public.request_crypto_withdrawal(numeric,text,text,text) to authenticated;
revoke all on function public.release_crypto_withdrawal(uuid,text) from public, anon, authenticated;
revoke all on function public.complete_crypto_withdrawal(uuid,text,bigint) from public, anon, authenticated;

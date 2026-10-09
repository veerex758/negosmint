-- Verified wallet ownership is separate from wallet_connections metadata.
-- Only the trusted verify-wallet-link Edge Function may create/consume challenges
-- or write verified address records. Never store signing keys or recovery phrases.

create table if not exists public.wallet_link_challenges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  nonce text not null unique,
  message text not null,
  chain_id bigint not null check (chain_id = 11155111),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz
);

create index if not exists wallet_link_challenges_user_created_idx
  on public.wallet_link_challenges(user_id, created_at desc);

create table if not exists public.verified_wallet_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  wallet_address text not null,
  chain_id bigint not null check (chain_id = 11155111),
  verified_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint verified_wallet_addresses_evm_address
    check (wallet_address ~ '^0x[0-9a-fA-F]{40}$')
);

alter table public.wallet_link_challenges enable row level security;
alter table public.verified_wallet_addresses enable row level security;

drop policy if exists "Users can view own verified wallet" on public.verified_wallet_addresses;
create policy "Users can view own verified wallet"
  on public.verified_wallet_addresses for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- No client access to challenges, and no client writes to verified records.
revoke all on public.wallet_link_challenges from public, anon, authenticated;
revoke all on public.verified_wallet_addresses from public, anon, authenticated;
grant select on public.verified_wallet_addresses to authenticated;

create or replace function public.consume_wallet_link_challenge(
  p_challenge_id uuid,
  p_user_id uuid,
  p_wallet_address text,
  p_chain_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge public.wallet_link_challenges%rowtype;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if p_chain_id <> 11155111
     or p_wallet_address !~ '^0x[0-9a-fA-F]{40}$' then
    raise exception 'Invalid wallet details';
  end if;

  select * into v_challenge
  from public.wallet_link_challenges
  where id = p_challenge_id
    and user_id = p_user_id
  for update;

  if not found then raise exception 'Challenge not found'; end if;
  if v_challenge.consumed_at is not null then
    raise exception 'Challenge already used';
  end if;
  if v_challenge.expires_at <= now() then
    raise exception 'Challenge expired';
  end if;
  if v_challenge.chain_id <> p_chain_id then
    raise exception 'Wrong chain';
  end if;

  update public.wallet_link_challenges
  set consumed_at = now()
  where id = p_challenge_id;

  insert into public.verified_wallet_addresses(
    user_id, wallet_address, chain_id, verified_at, revoked_at
  ) values (
    p_user_id, lower(p_wallet_address), p_chain_id, now(), null
  )
  on conflict (user_id) do update
    set wallet_address = excluded.wallet_address,
        chain_id = excluded.chain_id,
        verified_at = now(),
        revoked_at = null;
end;
$$;

revoke all on function public.consume_wallet_link_challenge(uuid, uuid, text, bigint)
  from public, anon, authenticated;
grant execute on function public.consume_wallet_link_challenge(uuid, uuid, text, bigint)
  to service_role;

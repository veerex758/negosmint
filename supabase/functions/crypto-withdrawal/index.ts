import { createClient } from "npm:@supabase/supabase-js@2";
import { Contract, JsonRpcProvider, Wallet, isAddress, parseUnits } from "npm:ethers@6";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ERC20_ABI = [
  "function transfer(address to, uint256 amount) returns (bool)",
  "function decimals() view returns (uint8)",
];

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return json({ error: "Missing authorization" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const publishableKeys = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  const anonKey = publishableKeys
    ? JSON.parse(publishableKeys)["default"]
    : Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
    return json({ error: "Server is not configured" }, 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return json({ error: "Invalid session" }, 401);

  let body: { amount?: number; asset?: string; network?: string; wallet_address?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const amount = Number(body.amount);
  const asset = String(body.asset ?? "").toUpperCase();
  const network = String(body.network ?? "").toUpperCase();
  const walletAddress = String(body.wallet_address ?? "");

  if (!Number.isFinite(amount) || amount <= 0) return json({ error: "Invalid amount" }, 400);
  if (!["USDT", "USDC"].includes(asset)) return json({ error: "Unsupported asset" }, 400);
  if (!["ETHEREUM", "BSC", "POLYGON", "ARBITRUM", "BASE"].includes(network)) {
    return json({ error: "Unsupported network" }, 400);
  }
  if (!isAddress(walletAddress)) return json({ error: "Invalid wallet address" }, 400);

  const { data: withdrawalId, error: reserveError } =
    await userClient.rpc("request_crypto_withdrawal", {
      p_amount: amount,
      p_asset: asset,
      p_network: network,
      p_wallet_address: walletAddress,
    });

  if (reserveError || !withdrawalId) {
    return json({ error: reserveError?.message ?? "Withdrawal could not be reserved" }, 400);
  }

  const failWithdrawal = async (reason: string) => {
    await admin.rpc("release_crypto_withdrawal", {
      p_withdrawal_id: withdrawalId,
      p_reason: reason.slice(0, 500),
    });
  };

  try {
    const rpcUrl = Deno.env.get(`RPC_URL_${network}`);
    const tokenAddress = Deno.env.get(`TOKEN_ADDRESS_${asset}_${network}`);
    const privateKey = Deno.env.get("CRYPTO_HOT_WALLET_PRIVATE_KEY");

    if (!rpcUrl || !tokenAddress || !privateKey) {
      await failWithdrawal("Crypto withdrawal network is not configured");
      return json({ error: "Crypto withdrawal is not configured for this network" }, 503);
    }

    const provider = new JsonRpcProvider(rpcUrl);
    const signer = new Wallet(privateKey, provider);
    const contract = new Contract(tokenAddress, ERC20_ABI, signer);
    const onChainDecimals = Number(await contract.decimals());
    const units = parseUnits(amount.toString(), onChainDecimals);
    const tx = await contract.transfer(walletAddress, units);

    await admin.from("withdrawals").update({
      status: "approved",
      tx_hash: tx.hash,
      transaction_ref: tx.hash,
    }).eq("id", withdrawalId).eq("user_id", user.id);

    const receipt = await tx.wait();
    if (!receipt || receipt.status !== 1) throw new Error("Blockchain transaction failed");

    const chainId = Number((await provider.getNetwork()).chainId);
    const { error: completeError } = await admin.rpc("complete_crypto_withdrawal", {
      p_withdrawal_id: withdrawalId,
      p_tx_hash: tx.hash,
      p_chain_id: chainId,
    });

    if (completeError) throw completeError;

    return json({
      ok: true,
      withdrawal_id: withdrawalId,
      asset,
      network,
      wallet_address: walletAddress,
      amount,
      tx_hash: tx.hash,
      chain_id: chainId,
      status: "completed",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Blockchain transfer failed";
    await failWithdrawal(message);
    return json({ error: "Blockchain transfer failed", withdrawal_id: withdrawalId }, 502);
  }
});

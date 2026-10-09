import { createClient } from "npm:@supabase/supabase-js@2";
import { getAddress, isAddress, verifyMessage } from "npm:ethers@6";
import { corsHeaders } from "../_shared/cors.ts";

const CHAIN_ID = 11155111; // Ethereum Sepolia only; matches the wallet V1.
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

function randomNonce(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return json({ error: "Authentication required" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Server is not configured" }, 500);
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: { user }, error: authError } = await authClient.auth.getUser();
    if (authError || !user) return json({ error: "Invalid session" }, 401);

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const body = await req.json().catch(() => null);
    if (!body || typeof body.action !== "string") {
      return json({ error: "Invalid request body" }, 400);
    }

    if (body.action === "create_challenge") {
      const nonce = randomNonce();
      const challengeId = crypto.randomUUID();
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
      const expiryText = expiresAt.toISOString();
      const message = [
        "NegosMint Wallet Ownership Verification",
        "Purpose: Link this self-custody wallet to the signed-in NegosMint Task Platform account.",
        `User ID: ${user.id}`,
        `Challenge ID: ${challengeId}`,
        `Nonce: ${nonce}`,
        `Chain ID: ${CHAIN_ID}`,
        `Expires At: ${expiryText}`,
        "This signature proves address control only. It does not authorize a transaction.",
        "If you did not initiate this request, reject it.",
      ].join("\n");

      const { error } = await admin.from("wallet_link_challenges").insert({
        id: challengeId,
        user_id: user.id,
        nonce,
        message,
        chain_id: CHAIN_ID,
        expires_at: expiryText,
      });
      if (error) {
        console.error("Could not create wallet-link challenge", error.message);
        return json({ error: "Could not create verification request" }, 500);
      }
      return json({
        challenge_id: challengeId,
        message,
        chain_id: CHAIN_ID,
        expires_at: expiryText,
      });
    }

    if (body.action === "verify_signature") {
      const challengeId = body.challenge_id;
      const message = body.message;
      const signature = body.signature;
      const claimedAddress = body.wallet_address;
      const chainId = Number(body.chain_id);

      if (typeof challengeId !== "string" ||
          typeof message !== "string" || message.length > 2000 ||
          typeof signature !== "string" || !/^0x[0-9a-fA-F]{130}$/.test(signature) ||
          typeof claimedAddress !== "string" || !isAddress(claimedAddress) ||
          chainId !== CHAIN_ID) {
        return json({ error: "Invalid verification data" }, 400);
      }

      const { data: challenge, error: challengeError } = await admin
        .from("wallet_link_challenges")
        .select("id,user_id,message,chain_id,expires_at,consumed_at")
        .eq("id", challengeId)
        .eq("user_id", user.id)
        .maybeSingle();

      if (challengeError) {
        console.error("Could not load wallet-link challenge", challengeError.message);
        return json({ error: "Could not verify wallet" }, 500);
      }
      if (!challenge || challenge.consumed_at || new Date(challenge.expires_at).getTime() <= Date.now()) {
        return json({ error: "Verification request expired or already used" }, 400);
      }
      if (challenge.chain_id !== CHAIN_ID || challenge.message !== message) {
        return json({ error: "Challenge does not match" }, 400);
      }

      let recoveredAddress: string;
      try {
        recoveredAddress = getAddress(verifyMessage(challenge.message, signature));
      } catch {
        return json({ error: "Invalid wallet signature" }, 400);
      }
      if (recoveredAddress.toLowerCase() !== claimedAddress.toLowerCase()) {
        return json({ error: "Signature does not match the supplied address" }, 400);
      }

      // The service-role-only SQL function consumes the challenge atomically
      // and records the verified address, preventing replay and client forgery.
      const { error: consumeError } = await admin.rpc("consume_wallet_link_challenge", {
        p_challenge_id: challenge.id,
        p_user_id: user.id,
        p_wallet_address: recoveredAddress,
        p_chain_id: CHAIN_ID,
      });
      if (consumeError) {
        return json({ error: "Verification request expired or already used" }, 409);
      }

      return json({
        verified: true,
        wallet_address: recoveredAddress,
        chain_id: CHAIN_ID,
      });
    }

    return json({ error: "Unsupported action" }, 400);
  } catch (error) {
    console.error("Wallet-link verification failed", error);
    return json({ error: "Wallet verification failed" }, 500);
  }
});

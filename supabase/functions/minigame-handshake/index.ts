import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";
import { encodeHex } from "https://deno.land/std@0.207.0/encoding/hex.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-client-nonce",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

// Honeypot de tiempo: Retraso asíncrono para despistar hackers de timing
const sleepRandomHoneypot = () => {
  const ms = Math.floor(Math.random() * (3000 - 1000 + 1) + 1000);
  return new Promise(resolve => setTimeout(resolve, ms));
};

const hashData = async (data: string, algorithm = "SHA-256") => {
  const buffer = await crypto.subtle.digest(algorithm, new TextEncoder().encode(data));
  return encodeHex(new Uint8Array(buffer));
};

const hashIp = (ip: string, salt: string) => hashData(ip + salt);

// HMAC-SHA256 challenge generation & validation
const hmacSign = async (payload: string, secret: string): Promise<string> => {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  return encodeHex(new Uint8Array(sig));
};

const hmacVerify = async (payload: string, secret: string, expected: string): Promise<boolean> => {
  const computed = await hmacSign(payload, secret);
  // Constant-time comparison via subtle digest equality
  if (computed.length !== expected.length) return false;
  const a = new TextEncoder().encode(computed);
  const b = new TextEncoder().encode(expected);
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const ipSalt = Deno.env.get("IP_HASH_SALT");
    const challengeSecret = Deno.env.get("CHALLENGE_SECRET");

    // Fail-closed: refuse to operate without required secrets
    if (!ipSalt || !challengeSecret) {
      console.error("FATAL: IP_HASH_SALT or CHALLENGE_SECRET env var missing");
      return jsonResponse({ success: false, error: "Server misconfiguration", reference_code: "0xERR-CFG" }, 200);
    }

    // 1. IP extraction & hashing
    const forwardedFor = req.headers.get("x-forwarded-for");
    const realIp = forwardedFor ? forwardedFor.split(',')[0].trim() : "unknown_ip";
    const hashedIp = await hashIp(realIp, ipSalt);

    // 2. Read and log client nonce (for future replay detection)
    const clientNonce = req.headers.get("x-client-nonce") ?? "";

    const supabaseAdmin = createClient(supabaseUrl, serviceKey, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    const body = await req.json();
    const action = body.action;

    // ─── ACTION: STATUS ─────────────────────────────────────────────────
    if (action === "status") {
      const { data, error } = await supabaseAdmin.rpc("get_minigame_block_status", {
        p_ip_hash: hashedIp,
      });

      if (error) {
        return jsonResponse({ blocked: false }, 200);
      }

      return jsonResponse(data ?? { blocked: false }, 200);
    }

    // ─── ACTION: START-SESSION ──────────────────────────────────────────
    if (action === "start-session") {
      // Generate a unique nonce for the challenge
      const challengeNonce = encodeHex(crypto.getRandomValues(new Uint8Array(16)));

      // Call RPC to create the session (without challenge yet — need session_id)
      const { data: sessionId, error } = await supabaseAdmin.rpc("start_minigame", {
        p_clue_id: body.clue_id,
        p_min_duration_seconds: body.min_duration_seconds || 0,
        p_ip_hash: hashedIp,
        p_challenge_hash: null,  // Will be updated below
        p_challenge_nonce: challengeNonce,
      });

      if (error) {
        await sleepRandomHoneypot();
        const isBlocked = error.message && error.message.includes("Blocked:");
        return jsonResponse({
          success: false,
          error: isBlocked ? "BLOCKED" : "VALIDATION_FAILED",
          reference_code: "0xERR-START",
        }, 200);
      }

      // Build the HMAC challenge: binds session to context
      const challengePayload = `${sessionId}:${hashedIp}:${challengeNonce}`;
      const challengeToken = await hmacSign(challengePayload, challengeSecret);

      // Store challenge_hash in the session row via RPC (bypasses RLS safely)
      const updateRes = await supabaseAdmin.rpc("set_minigame_challenge", {
        p_session_id: sessionId,
        p_challenge_hash: challengeToken,
        p_challenge_nonce: challengeNonce,
      });
      if (updateRes.error) {
        console.error("[minigame-handshake] challenge update failed", updateRes.error);
      }

      return jsonResponse({
        success: true,
        session_id: sessionId,
        challenge_token: challengeToken,
      });
    }

    // ─── ACTION: VERIFY-SESSION ─────────────────────────────────────────
    if (action === "verify-session") {
      const sessionId = body.session_id;
      const receivedChallenge = body.challenge_token ?? "";

      // Fetch session to get stored challenge data
      const { data: session } = await supabaseAdmin
        .from("minigame_sessions")
        .select("challenge_hash, challenge_nonce, ip_hash")
        .eq("id", sessionId)
        .single();

      let challengeValid = false;

      if (session?.challenge_hash && session?.challenge_nonce) {
        // Reconstruct the payload using stored nonce + current IP
        const verifyPayload = `${sessionId}:${hashedIp}:${session.challenge_nonce}`;
        challengeValid = await hmacVerify(verifyPayload, challengeSecret, receivedChallenge);

        if (!challengeValid) {
          await sleepRandomHoneypot();
          return jsonResponse({
            success: false,
            error: "CHALLENGE_MISMATCH",
            reference_code: "0xERR-HMAC"
          }, 200);
        }
      }

      const { data, error } = await supabaseAdmin.rpc("verify_and_complete_minigame", {
        p_session_id: sessionId,
        p_answer: body.p_answer ?? body.answer ?? "",
        p_result: body.p_result ?? body.result ?? {},
        p_ip_hash: hashedIp,
        p_challenge_valid: challengeValid,
      });

      if (error || data?.success === false) {
        await sleepRandomHoneypot();
        if (data) {
          return jsonResponse(data as Record<string, unknown>, 200);
        }
        return jsonResponse({
          success: false,
          error: "VALIDATION_FAILED",
          reference_code: "0xERR-992A-4B"
        }, 200);
      }

      return jsonResponse(data ?? {});
    }

    // ─── ACTION: SKIP-CLUE (Admin-only via Edge Function) ───────────────
    if (action === "skip-clue") {
      const { data, error } = await supabaseAdmin.rpc("admin_skip_clue", {
        p_clue_id: body.clue_id,
      });

      if (error) {
        return jsonResponse({ success: false, error: error.message, reference_code: "0xERR-SKIP" }, 200);
      }

      return jsonResponse(data ?? { success: true });
    }

    return jsonResponse({ success: false, error: "Invalid action", reference_code: "0xERR-ACTION" }, 200);
  } catch (err) {
    console.error("minigame-handshake error:", err);
    return jsonResponse({ success: false, error: "Internal Server Error", reference_code: "0xERR-500" }, 200);
  }
});

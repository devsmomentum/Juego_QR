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
  const ms = Math.floor(Math.random() * (3000 - 1000 + 1) + 1000); // Aleatorio entre 1 y 3 segundos
  return new Promise(resolve => setTimeout(resolve, ms));
};

const hashIp = async (ip: string, salt: string) => {
  const message = new TextEncoder().encode(ip + salt);
  const hashBuffer = await crypto.subtle.digest("SHA-256", message);
  return encodeHex(hashBuffer);
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const ipSalt = Deno.env.get("IP_HASH_SALT") ?? "default_secure_salt_replace_me";

    // 1. Extracción y Hasheo de IP Real Inevadible
    const forwardedFor = req.headers.get("x-forwarded-for");
    const realIp = forwardedFor ? forwardedFor.split(',')[0].trim() : "unknown_ip";
    const hashedIp = await hashIp(realIp, ipSalt);

    const supabaseAdmin = createClient(supabaseUrl, serviceKey, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } }, // Auth contextual transferida
    });

    const body = await req.json();
    const action = body.action;

    if (action === "start-session") {
      const { data, error } = await supabaseAdmin.rpc("start_minigame", {
        p_clue_id: body.clue_id,
        p_min_duration_seconds: body.min_duration_seconds || 0,
        p_ip_hash: hashedIp,
      });

      if (error) {
        await sleepRandomHoneypot(); 
        const isBlocked = error.message && error.message.includes("Blocked:");
        // CAMBIO CRÍTICO: Devolver HTTP 200 en lugar de 403 para que el SDK de Flutter no lo convierta en FunctionException
        return jsonResponse({ success: false, error: isBlocked ? "BLOCKED" : "VALIDATION_FAILED", reference_code: "0xERR-START" }, 200);
      }
      return jsonResponse({ success: true, session_id: data });
    }

    if (action === "verify-session") {
      const { data, error } = await supabaseAdmin.rpc("verify_and_complete_minigame", {
        p_session_id: body.session_id,
        p_answer: body.p_answer ?? body.answer ?? "",
        p_result: body.p_result ?? body.result ?? {},
        p_ip_hash: hashedIp,
      });

      if (error || data?.success === false) {
        await sleepRandomHoneypot(); 
        return jsonResponse({
          success: false, 
          error: data?.error ?? "VALIDATION_FAILED", 
          reference_code: data?.reference_code ?? "0xERR-992A-4B" 
        }, 200);
      }

      return jsonResponse(data ?? {});
    }

    return jsonResponse({ success: false, error: "Invalid action", reference_code: "0xERR-ACTION" }, 200);
  } catch (err) {
    return jsonResponse({ success: false, error: "Internal Server Error", reference_code: "0xERR-500" }, 200);
  }
});

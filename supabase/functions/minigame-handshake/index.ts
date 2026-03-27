// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-client-nonce",
};

function getClientIp(req: Request): string {
  const forwardedFor = req.headers.get("x-forwarded-for");
  if (forwardedFor && forwardedFor.length > 0) {
    return forwardedFor.split(",")[0].trim();
  }
  const realIp = req.headers.get("x-real-ip");
  if (realIp && realIp.length > 0) {
    return realIp.trim();
  }
  return req.headers.get("cf-connecting-ip") ?? "";
}

async function sha256Hex(input: string): Promise<string> {
  if (!input) return "";
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const ipSalt = Deno.env.get("IP_HASH_SALT") ?? "";

    if (!supabaseUrl || !serviceKey || !ipSalt) {
      return jsonResponse({ error: "Server misconfigured" }, 500);
    }

    const supabaseClient = createClient(
      supabaseUrl,
      serviceKey,
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization") ?? "" },
        },
      },
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const body = await req.json();
    const action = body?.action;

    const ip = getClientIp(req);
    const ipHash = await sha256Hex(`${ipSalt}:${ip}`);

    if (action === "start-session") {
      const clueId = body?.clue_id;
      const minDurationSeconds = Number(body?.min_duration_seconds ?? 0);

      if (!clueId || Number.isNaN(minDurationSeconds)) {
        return jsonResponse({ error: "Invalid payload" }, 400);
      }

      const { data, error } = await supabaseClient.rpc("start_minigame", {
        p_clue_id: clueId,
        p_min_duration_seconds: minDurationSeconds,
        p_ip_hash: ipHash || null,
      });

      if (error) {
        console.error("[start-session] RPC error:", error);
        return jsonResponse({ error: "Forbidden" }, 403);
      }

      return jsonResponse({ session_id: data });
    }

    if (action === "status") {
      const { data, error } = await supabaseClient.rpc(
        "get_minigame_block_status",
        {
          p_ip_hash: ipHash || null,
        },
      );

      if (error) {
        console.error("[status] RPC error:", error);
        return jsonResponse({ error: "Forbidden" }, 403);
      }

      return jsonResponse(data ?? {});
    }

    if (action === "verify-session") {
      const sessionId = body?.session_id;
      const answer = body?.p_answer ?? "";
      const result = body?.p_result ?? {};

      if (!sessionId) {
        return jsonResponse({ error: "Missing session_id" }, 400);
      }

      const { data, error } = await supabaseClient.rpc(
        "verify_and_complete_minigame",
        {
          p_session_id: sessionId,
          p_answer: answer,
          p_result: result,
          p_ip_hash: ipHash || null,
        },
      );

      if (error) {
        console.error("[verify-session] RPC error:", error);
        return jsonResponse({ error: "Forbidden" }, 403);
      }

      // Forward security-related rejections (TOO_FAST, SESSION_EXPIRED)
      // with the full payload so Flutter can show the correct UI.
      // Real auth errors (Unauthorized, Forbidden, Session not found)
      // still get 403 to block the request.
      if (data?.success === false) {
        const errCode = data?.error;
        if (errCode === "TOO_FAST" || errCode === "SESSION_EXPIRED") {
          console.warn("[verify-session] Timing rejection:", errCode);
          return jsonResponse(data, 200);
        }
        console.warn("[verify-session] Security rejection:", errCode);
        return jsonResponse({ error: "Forbidden" }, 403);
      }

      return jsonResponse(data ?? {});
    }

    return jsonResponse({ error: "Invalid action" }, 400);
  } catch (e) {
    console.error("[minigame-handshake] Unhandled error:", e);
    return jsonResponse({ error: "Server error" }, 500);
  }
});

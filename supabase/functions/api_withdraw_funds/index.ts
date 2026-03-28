import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Use Service Role for safe DB operations (balance updates)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Authenticate User properly
    const authToken = req.headers.get("Authorization");
    if (!authToken) throw new Error("Missing Authorization header");

    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(authToken.replace("Bearer ", ""));

    if (userError || !user) {
      throw new Error("Unauthorized");
    }

    // Updated to accept payment_method_id
    const { plan_id, payment_method_id, bank, dni, phone, cta } = await req.json();

    if (!plan_id) {
      throw new Error("Missing required field: plan_id");
    }

    if (!payment_method_id && (!bank || !dni || (!phone && !cta))) {
      throw new Error(
        "Missing required fields: plan_id and either payment_method_id or legacy fields (bank, dni, phone/cta)",
      );
    }

    console.log(
      `[api_withdraw_funds] Processing withdrawal for user ${user.id}, plan_id: ${plan_id}`,
    );

    // 1. ATOMIC REQUEST CREATION (RPC)
    const { data: requestData, error: requestError } = await supabaseAdmin.rpc(
      "create_withdrawal_request",
      {
        p_user_id: user.id,
        p_plan_id: plan_id,
        p_payment_method_id: payment_method_id ?? null,
      },
    );

    if (requestError || !requestData) {
      console.error("Withdrawal request error:", requestError);
      throw new Error(requestError?.message || "Error creando retiro");
    }

    const requestId = requestData.request_id as string;
    const withdrawalType = requestData.gateway as string;
    const amountUsd = requestData.amount_usd as number;
    const amountVes = requestData.amount_ves as number | null;
    const finalBank = requestData.bank_code as string | null;
    const finalDni = requestData.dni as string | null;
    const finalPhone = requestData.phone_number as string | null;
    const finalStripeEmail = requestData.stripe_email as string | null;

    console.log(
      `[api_withdraw_funds] Request created: ${requestId}, Type: ${withdrawalType}`,
    );

    // 4. BRANCH LOGIC BY TYPE
    if (withdrawalType === "stripe") {
      // --- STRIPE WITHDRAWAL FLOW ---
      // For now, we record it as PENDING for manual processing
      // In a real production app, you would call Stripe Payouts API here.
      
      await supabaseAdmin.rpc("mark_withdrawal_pending", {
        p_request_id: requestId,
        p_provider_data: {
          gateway: "stripe",
          email: finalStripeEmail,
        },
      });

      return new Response(
        JSON.stringify({
          success: true,
          message: "Retiro solicitado exitosamente. Se procesará pronto.",
          data: {
            type: "stripe",
            email: finalStripeEmail,
            amount_usd: amountUsd,
            transaction_id: requestId,
          },
          pending: true,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );

    } else {
      // --- PAGO MOVIL FLOW (EXISTING) ---
      // 2. GET BCV EXCHANGE RATE FROM APP_CONFIG
     // Use order+limit instead of .single() so duplicate rows during DB cleanup
    // don't throw a 406 error and block all withdrawals.
    const { data: configRows, error: configError } = await supabaseAdmin
      .from("app_config")
      .select("value, updated_at")
      .eq("key", "bcv_exchange_rate")
      .order("updated_at", { ascending: false })
      .limit(1);

    const configData = configRows?.[0] ?? null;

    if (configError || !configData) {
      console.error("Exchange rate fetch error:", configError);
      throw new Error(
        "No se pudo obtener la tasa de cambio. Contacte a soporte.",
      );
    }

    // ── FAIL-SAFE: "26 Hour Rule" ──────────────────────────────────────────
    // If the BCV rate hasn't been updated in 26 hours (1 day + 2h grace),
    // block ALL withdrawals to protect the treasury from stale exchange rates.
    const STALE_THRESHOLD_MS = 26 * 60 * 60 * 1000; // 26 hours in ms
    const updatedAt = configData.updated_at
      ? new Date(configData.updated_at)
      : null;
    const now = new Date();

    if (
      !updatedAt ||
      now.getTime() - updatedAt.getTime() > STALE_THRESHOLD_MS
    ) {
      const hoursAgo = updatedAt
        ? (
            (now.getTime() - updatedAt.getTime()) /
            (1000 * 60 * 60)
          ).toFixed(1)
        : "N/A";
      console.error(
        `[api_withdraw_funds] ⛔ FAIL-SAFE TRIGGERED: BCV rate is STALE. ` +
          `Last update: ${updatedAt?.toISOString() ?? "NEVER"} (${hoursAgo}h ago)`,
      );
      throw new Error(
        "El sistema de cambio está en mantenimiento temporal. " +
          "La tasa de cambio no está actualizada. Intente más tarde.",
      );
    }

    console.log(
      `[api_withdraw_funds] ✅ BCV rate freshness OK. Last update: ${updatedAt.toISOString()}`,
    );
    // ── END FAIL-SAFE ──────────────────────────────────────────────────────

    // Parse the exchange rate (stored as jsonb string like "56.50")
    const bcvRate = parseFloat(configData.value);
    if (isNaN(bcvRate) || bcvRate <= 0) {
      throw new Error("Tasa de cambio inválida configurada en el sistema");
    }

    // 3. CALCULATE VES AMOUNT
    const effectiveAmountVes = amountVes ?? (amountUsd * bcvRate);
    console.log(
      `[api_withdraw_funds] Exchange: $${amountUsd} USD × ${bcvRate} = ${effectiveAmountVes.toFixed(2)} VES`,
    );

    // 4. CALL PAGO A PAGO WITH VES AMOUNT
    const pagoApiKey = Deno.env.get("PAGO_PAGO_API_KEY")!;
    const withdrawUrl = `https://mqlboutjgscjgogqbsjc.supabase.co/functions/v1/api_instant_credit_delivery`;

    // NOTE: Keep DNI and Phone as-is - Pago a Pago expects exact format
    // DNI: "V19400121" (with prefix)
    // Phone: "04242382511" (with leading zero)
    console.log(
      `[api_withdraw_funds] Sending Withdrawal: DNI=${finalDni}, Phone=${finalPhone}, Bank=${finalBank}, Amount=${amountVes.toFixed(2)} VES`,
    );

    // IMPORTANT: Only send the 4 required fields for Pago Móvil
    // Do NOT include null/undefined fields like 'cta' as they may cause errors
    const payload: Record<string, unknown> = {
      amount: effectiveAmountVes, // VES amount (converted from USD)
      bank: finalBank,
      phone: finalPhone, // Keep as-is with leading zero
      dni: finalDni,     // Keep as-is with prefix (V/E/J/P/G)
    };

    let apiSuccess = false;
    let apiPending = false;
    let apiResponseData: Record<string, unknown> | null = null;

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 15000);

      const response = await fetch(withdrawUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          pago_pago_api: pagoApiKey,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      apiResponseData = await response.json() as Record<string, unknown>;
      
      // Log the full response for debugging
      console.log(`[api_withdraw_funds] Pago a Pago Response:`, JSON.stringify(apiResponseData));
      
      // IMPROVED SUCCESS DETECTION:
      // 1. Check for transaction_id as definitive proof of success
      // 2. Pago a Pago may return success:false but still process the payment
      const dataObj = apiResponseData?.data as Record<string, unknown> | undefined;
      const hasTransactionId = !!dataObj?.transaction_id;
      const hasCompletedStatus = dataObj?.status === "completed";
      const explicitSuccess = apiResponseData?.success === true;
      
      // Consider success if we have a transaction_id OR explicit success
      apiSuccess = response.ok && (hasTransactionId || explicitSuccess || hasCompletedStatus);

      const explicitFailure =
        apiResponseData?.success === false && !hasTransactionId && !hasCompletedStatus;
      if (!apiSuccess && explicitFailure) {
        apiPending = false;
      } else if (!apiSuccess) {
        apiPending = true;
      }
      
      console.log(`[api_withdraw_funds] Success evaluation: response.ok=${response.ok}, hasTransactionId=${hasTransactionId}, hasCompletedStatus=${hasCompletedStatus}, explicitSuccess=${explicitSuccess}, FINAL=${apiSuccess}`);
      
    } catch (netError) {
      console.error("Network error calling Pago a Pago:", netError);
      apiSuccess = false;
      apiPending = true;
    }

    // 6. HANDLE FAILURE -> REFUND CLOVERS
    if (!apiSuccess && !apiPending) {
      console.error("Withdrawal Failed.", apiResponseData);

      await supabaseAdmin.rpc("mark_withdrawal_failed", {
        p_request_id: requestId,
        p_provider_data: apiResponseData,
        p_refund: true,
      });

      const failureMsg =
        apiResponseData?.message ??
        JSON.stringify(apiResponseData) ??
        "Withdrawal failed at payment provider (No detail).";
      throw new Error(`Retiro fallido: ${failureMsg}. Tréboles reembolsados.`);
    }

      if (apiPending) {
      await supabaseAdmin.rpc("mark_withdrawal_pending", {
        p_request_id: requestId,
        p_provider_data: {
          ...apiResponseData,
          pending_reason: "provider_latency_or_unknown",
        },
      });

      return new Response(
        JSON.stringify({
          success: true,
          pending: true,
          message:
            "Retiro en proceso. Te notificaremos cuando se confirme el pago.",
          data: apiResponseData,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        },
      );
    }

    // 7. LOG SUCCESSFUL TRANSACTION
    // Safe access to nested data properties
    const responseData = apiResponseData?.data as Record<string, unknown> | undefined;
    const detailsData = responseData?.details as Record<string, unknown> | undefined;
    
    await supabaseAdmin.rpc("mark_withdrawal_completed", {
      p_request_id: requestId,
      p_provider_data: {
        ...apiResponseData,
        transaction_id: responseData?.transaction_id,
        reference: detailsData?.external_reference || responseData?.reference,
      },
    });

    return new Response(
      JSON.stringify({
        success: true,
        data: apiResponseData,
        message: "Retiro procesado exitosamente.",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );

    } // Close else (branch for pago_movil)
  } catch (error) {
    console.error("Withdrawal flow error:", error);
    return new Response(
      JSON.stringify({ error: error.message, success: false }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      },
    );
  }
});

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

    // 1. FETCH AND VALIDATE WITHDRAWAL PLAN
    const { data: plan, error: planError } = await supabaseAdmin
      .from("transaction_plans")
      .select("id, name, amount, price, is_active, type")
      .eq("id", plan_id)
      .eq("type", "withdraw") // Security: Ensure it is a WITHDRAW plan
      .single();

    if (planError) {
      console.error("Plan fetch error:", planError);
      throw new Error(`Plan inválido: ${planError.message}`);
    }

    if (!plan) {
      throw new Error("Plan de retiro no encontrado");
    }

    if (!plan.is_active) {
      throw new Error("El plan de retiro seleccionado no está disponible");
    }

    // CRITICAL: Use values from DATABASE, not from client
    // CRITICAL: Use values from DATABASE
    const cloversCost = plan.amount;
    const amountUsd = plan.price;

    // 2. FETCH AND VALIDATE PAYMENT METHOD
    let withdrawalType = "pago_movil";
    let finalBank = bank;
    let finalDni = dni;
    let finalPhone = phone;
    let finalStripeEmail: string | null = null;

    if (payment_method_id) {
      const { data: pm, error: pmError } = await supabaseAdmin
        .from("user_payment_methods")
        .select("*")
        .eq("id", payment_method_id)
        .eq("user_id", user.id)
        .single();

      if (pmError || !pm) {
        console.error("Payment method fetch error:", pmError);
        throw new Error("Método de pago no encontrado");
      }

      withdrawalType = pm.type || "pago_movil";
      if (withdrawalType === "stripe") {
        finalStripeEmail = pm.identifier;
        if (!finalStripeEmail) throw new Error("Email de Stripe no configurado");
      } else {
        finalBank = pm.bank_code;
        finalDni = pm.dni;
        finalPhone = pm.phone_number;
      }
    }

    console.log(
      `[api_withdraw_funds] Plan validated: ${plan.name}, Clovers Cost: ${cloversCost}, Amount: $${amountUsd} USD, Type: ${withdrawalType}`,
    );

    // 3. COMMON LOGIC: VALIDATE BALANCE
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("clovers")
      .eq("id", user.id)
      .single();

    if (profileError || !profile) {
      throw new Error("Profile not found");
    }

    if (profile.clovers < cloversCost) {
      throw new Error(
        `Saldo insuficiente: Tienes ${profile.clovers} tréboles, necesitas ${cloversCost}`,
      );
    }

    // Deduct clovers immediately (will refund on failure)
    const { error: deductError } = await supabaseAdmin
      .from("profiles")
      .update({ clovers: profile.clovers - cloversCost })
      .eq("id", user.id);

    if (deductError) throw new Error("Error al descontar tréboles");

    console.log(
      `[api_withdraw_funds] Deducted ${cloversCost} clovers from user. New balance: ${profile.clovers - cloversCost}`,
    );

    // 4. BRANCH LOGIC BY TYPE
    if (withdrawalType === "stripe") {
      // --- STRIPE WITHDRAWAL FLOW ---
      // For now, we record it as PENDING for manual processing
      // In a real production app, you would call Stripe Payouts API here.
      
      const transactionId = `ST-${Date.now()}`;
      
      // Log Success (as pending/manual for now)
      await supabaseAdmin.from("payment_transactions").insert({
        user_id: user.id,
        amount: amountUsd,
        type: "WITHDRAWAL",
        status: "PENDING", // PENDING since it needs manual fulfillment
        provider_data: {
          gateway: "stripe",
          email: finalStripeEmail,
          plan_id: plan.id,
          plan_name: plan.name,
          clovers_cost: cloversCost,
          amount_usd: amountUsd,
        },
        order_id: transactionId,
      });

      // Log in Wallet Ledger
      const { error: ledgerError } = await supabaseAdmin
        .from("wallet_ledger")
        .insert({
          user_id: user.id,
          amount: -cloversCost,
          description: `Retiro Stripe: ${plan.name} - $${amountUsd} USD - Ref: ${finalStripeEmail}`,
          order_id: null,
          metadata: {
            type: "withdrawal",
            gateway: "stripe",
            email: finalStripeEmail,
            plan_id: plan.id,
            plan_name: plan.name,
            clovers_cost: cloversCost,
            amount_usd: amountUsd,
          },
        });

      if (ledgerError) console.error("Ledger Log Error (Non-Fatal):", ledgerError);

      return new Response(
        JSON.stringify({
          success: true,
          message: "Retiro solicitado exitosamente. Se procesará pronto.",
          data: {
            type: "stripe",
            email: finalStripeEmail,
            amount_usd: amountUsd,
            transaction_id: transactionId,
          }
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
    const amountVes = amountUsd * bcvRate;
    console.log(
      `[api_withdraw_funds] Exchange: $${amountUsd} USD × ${bcvRate} = ${amountVes.toFixed(2)} VES`,
    );

    // 4. CALL PAGO A PAGO WITH VES AMOUNT
    const pagoApiKey = Deno.env.get("PAGO_PAGO_API_KEY")!;
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const withdrawUrl = `${supabaseUrl}/functions/v1/api_instant_credit_delivery`;

    // NOTE: Keep DNI and Phone as-is - Pago a Pago expects exact format
    // DNI: "V19400121" (with prefix)
    // Phone: "04242382511" (with leading zero)
    console.log(
      `[api_withdraw_funds] Sending Withdrawal: DNI=${finalDni}, Phone=${finalPhone}, Bank=${finalBank}, Amount=${amountVes.toFixed(2)} VES`,
    );

    // IMPORTANT: Only send the 4 required fields for Pago Móvil
    // Do NOT include null/undefined fields like 'cta' as they may cause errors
    const payload: Record<string, unknown> = {
      amount: amountVes, // VES amount (converted from USD)
      bank: finalBank,
      phone: finalPhone, // Keep as-is with leading zero
      dni: finalDni,     // Keep as-is with prefix (V/E/J/P/G)
    };

    let apiSuccess = false;
    let apiResponseData: Record<string, unknown> | null = null;

    try {
      const response = await fetch(withdrawUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          pago_pago_api: pagoApiKey,
        },
        body: JSON.stringify(payload),
      });

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
      
      console.log(`[api_withdraw_funds] Success evaluation: response.ok=${response.ok}, hasTransactionId=${hasTransactionId}, hasCompletedStatus=${hasCompletedStatus}, explicitSuccess=${explicitSuccess}, FINAL=${apiSuccess}`);
      
    } catch (netError) {
      console.error("Network error calling Pago a Pago:", netError);
      apiSuccess = false;
    }

    // 6. HANDLE FAILURE -> REFUND CLOVERS
    if (!apiSuccess) {
      console.error("Withdrawal Failed. Refunding clovers...", apiResponseData);

      // Fetch fresh balance to be safe regarding concurrency
      const { data: currentProfile } = await supabaseAdmin
        .from("profiles")
        .select("clovers")
        .eq("id", user.id)
        .single();

      if (currentProfile) {
        await supabaseAdmin
          .from("profiles")
          .update({ clovers: currentProfile.clovers + cloversCost })
          .eq("id", user.id);

        // Log Refund in Wallet Ledger
        const { error: refundLedgerError } = await supabaseAdmin
          .from("wallet_ledger")
          .insert({
            user_id: user.id,
            amount: cloversCost, // Positive for refund (clovers returned)
            description: `Reembolso por fallo en retiro - Plan: ${plan.name}`,
            order_id: null,
            metadata: {
              plan_id: plan.id,
              plan_name: plan.name,
              amount_usd: amountUsd,
              amount_ves: amountVes,
              bcv_rate: bcvRate,
              api_response: apiResponseData,
            },
          });

        if (refundLedgerError) {
          console.error(
            "CRITICAL: Failed to log refund in wallet_ledger:",
            refundLedgerError,
          );
        }
      }

      const failureMsg =
        apiResponseData?.message ??
        JSON.stringify(apiResponseData) ??
        "Withdrawal failed at payment provider (No detail).";
      throw new Error(`Retiro fallido: ${failureMsg}. Tréboles reembolsados.`);
    }

    // 7. LOG SUCCESSFUL TRANSACTION
    // Safe access to nested data properties
    const responseData = apiResponseData?.data as Record<string, unknown> | undefined;
    const detailsData = responseData?.details as Record<string, unknown> | undefined;
    
    await supabaseAdmin.from("payment_transactions").insert({
      user_id: user.id,
      amount: amountVes,
      type: "WITHDRAWAL",
      status: "COMPLETED",
      provider_data: {
        ...apiResponseData,
        plan_id: plan.id,
        plan_name: plan.name,
        clovers_cost: cloversCost,
        amount_usd: amountUsd,
        bcv_rate: bcvRate,
      },
      order_id: responseData?.transaction_id || `WD-${Date.now()}`,
    });

    // 8. LOG IN WALLET LEDGER
    const referenceInfo =
      detailsData?.external_reference ||
      responseData?.reference ||
      "N/A";
    const transactionId = responseData?.transaction_id;

    const { error: ledgerError } = await supabaseAdmin
      .from("wallet_ledger")
      .insert({
        user_id: user.id,
        amount: -cloversCost, // Negative for withdrawal (clovers spent)
        description: `Retiro: ${plan.name} - $${amountUsd} USD (${amountVes.toFixed(2)} VES) - Ref: ${referenceInfo}`,
        order_id: null,
        metadata: {
          plan_id: plan.id,
          plan_name: plan.name,
          clovers_cost: cloversCost,
          amount_usd: amountUsd,
          amount_ves: amountVes,
          bcv_rate: bcvRate,
          transaction_id: transactionId,
          api_response: apiResponseData,
        },
      });

    if (ledgerError) {
      console.error(
        "CRITICAL: Failed to log withdrawal in wallet_ledger:",
        ledgerError,
      );
      return new Response(
        JSON.stringify({
          success: true,
          data: apiResponseData,
          warning:
            "Transaction completed but ledger update failed. Contact support.",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        },
      );
    }

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

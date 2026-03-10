import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, pago_pago_api",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client for user authentication
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      },
    );

    // 1. AUTHENTICATE USER
    const {
      data: { user },
    } = await supabaseClient.auth.getUser();

    if (!user) {
      throw new Error("Unauthorized");
    }

    // 2. PARSE REQUEST - Only plan_id is accepted (SECURITY: no amount from client)
    const { plan_id } = await req.json();

    if (!plan_id) {
      throw new Error("Missing plan_id parameter");
    }

    console.log(
      `[api_pay_orders] Processing payment for user ${user.id}, plan_id: ${plan_id}`,
    );

    // 3. INITIALIZE ADMIN CLIENT (for bypassing RLS)
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceRoleKey) {
      console.error("CRITICAL: SUPABASE_SERVICE_ROLE_KEY is missing!");
      throw new Error("Server Misconfiguration: Missing DB Permissions");
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceRoleKey,
    );

    // 4. VALIDATE PLAN FROM DATABASE (Unified Table)
    const { data: plan, error: planError } = await supabaseAdmin
      .from("transaction_plans")
      .select("id, name, amount, price, is_active, type")
      .eq("id", plan_id)
      .eq("type", "buy") // Security: Ensure it is a BUY plan
      .single();

    if (planError) {
      console.error("Plan fetch error:", planError);
      throw new Error(`Plan inválido: ${planError.message}`);
    }

    if (!plan) {
      throw new Error("Plan no encontrado");
    }

    if (!plan.is_active) {
      throw new Error("El plan seleccionado no está disponible");
    }

    // CRITICAL: Use price from DATABASE, not from client
    const priceUsd = plan.price;
    const cloversQuantity = plan.amount;

    console.log(
      `[api_pay_orders] Plan validated: ${plan.name}, Price: $${priceUsd} USD, Clovers: ${cloversQuantity}`,
    );

    // 5. FETCH USER PROFILE DATA (for payment gateway)
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("email, phone, dni")
      .eq("id", user.id)
      .single();

    if (profileError || !profile) {
      throw new Error("Perfil de usuario incompleto");
    }

    const { email, phone, dni } = profile;

    if (!email || !phone || !dni) {
      throw new Error("Perfil incompleto. Verifique email, teléfono y DNI.");
    }

    // 6. GET BCV EXCHANGE RATE and GATEWAY FEE from app_config
    const { data: configRows, error: configError } = await supabaseAdmin
      .from("app_config")
      .select("key, value")
      .in("key", ["bcv_exchange_rate", "gateway_fee_percentage"]);

    if (configError || !configRows || configRows.length === 0) {
      console.error("Config fetch error:", configError);
      throw new Error(
        "No se pudo obtener la configuración del sistema. Intente más tarde.",
      );
    }

    const configMap = Object.fromEntries(
      configRows.map((r: { key: string; value: string }) => [r.key, r.value]),
    );

    const bcvRate = parseFloat(configMap["bcv_exchange_rate"]);
    if (isNaN(bcvRate) || bcvRate <= 0) {
      throw new Error("Tasa de cambio inválida configurada en el sistema");
    }

    const gatewayFeePercent = parseFloat(configMap["gateway_fee_percentage"] ?? "0");
    if (isNaN(gatewayFeePercent) || gatewayFeePercent < 0) {
      throw new Error("Porcentaje de comisión inválido configurado en el sistema");
    }

    // Convert USD to VES (API requires VES)
    const amountVesBase = priceUsd * bcvRate;
    const feeVes = amountVesBase / (1 - (gatewayFeePercent / 100));
    const amountVes = amountVesBase + feeVes;

    console.log(
      `[api_pay_orders] Exchange: $${priceUsd} USD × ${bcvRate} = ${amountVesBase.toFixed(2)} VES (base) + ${feeVes.toFixed(2)} VES (${gatewayFeePercent}% fee) = ${amountVes.toFixed(2)} VES (total)`,
    );

    // Calculate expiration (30 minutes)
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();

    // 7. GENERATE VALIDATION CODE (for Pago Móvil manual validation)
    const { data: codeResult, error: codeError } = await supabaseAdmin.rpc(
      "generate_validation_code",
    );

    if (codeError || !codeResult) {
      console.error("Validation code generation failed:", codeError);
      throw new Error("Error generando código de validación");
    }

    const validationCode = codeResult as string;

    // Generate a local order reference
    const localOrderId = `MPAY-${Date.now()}-${user.id.substring(0, 8)}`;

    console.log(
      `[api_pay_orders] Validation code: ${validationCode}, ref: ${localOrderId}`,
    );

    // 8. PERSIST ORDER TO DATABASE
    const { data: insertedOrder, error: dbError } = await supabaseAdmin
      .from("clover_orders")
      .insert({
        user_id: user.id,
        plan_id: plan.id,
        amount: priceUsd,
        currency: "USD",
        status: "pending",
        pago_pago_order_id: localOrderId,
        validation_code: validationCode,
        expires_at: expiresAt,
        extra_data: {
          plan_name: plan.name,
          clovers_amount: cloversQuantity,
          price_usd: priceUsd,
          amount_ves_before_fee: amountVesBase,
          gateway_fee_percent: gatewayFeePercent,
          fee_ves: feeVes,
          amount_ves_total: amountVes,
          bcv_rate: bcvRate,
          initiated_at: new Date().toISOString(),
          payment_method: "pago_movil",
          function_version: "v7-mpay-local",
        },
      })
      .select("id")
      .single();

    if (dbError || !insertedOrder) {
      console.error("CRITICAL DB ERROR:", dbError);
      throw new Error(`Database Persistence Failed: ${dbError?.message}`);
    }

    console.log(
      `[api_pay_orders] Order created: ${insertedOrder.id}, code: ${validationCode}`,
    );

    // 9. RETURN SUCCESS RESPONSE
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          db_order_id: insertedOrder.id,
          validation_code: validationCode,
          amount_ves: amountVes,
          plan: {
            id: plan.id,
            name: plan.name,
            clovers: cloversQuantity,
            price_usd: priceUsd,
          },
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error) {
    console.error("[api_pay_orders] Error:", error);
    return new Response(
      JSON.stringify({
        error: error.message,
        success: false,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      },
    );
  }
});

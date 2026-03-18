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
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      },
    );

    const {
      data: { user },
    } = await supabaseClient.auth.getUser();
    if (!user) throw new Error("Unauthorized");

    const { plan_id } = await req.json();
    if (!plan_id) throw new Error("Missing plan_id parameter");

    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceRoleKey,
    );

    // 1. OBTENER DATOS (Plan, Perfil y Tasas) - Simplificado por brevedad
    const { data: plan } = await supabaseAdmin
      .from("transaction_plans")
      .select("*")
      .eq("id", plan_id)
      .single();
    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("*")
      .eq("id", user.id)
      .single();
    const { data: configRows } = await supabaseAdmin
      .from("app_config")
      .select("key, value")
      .in("key", ["bcv_exchange_rate", "gateway_fee_percentage"]);

    if (!plan || !profile || !configRows)
      throw new Error("Datos incompletos para procesar la orden");

    const configMap = Object.fromEntries(
      configRows.map((r: any) => [r.key, r.value]),
    );
    const bcvRate = parseFloat(configMap["bcv_exchange_rate"]);
    const gatewayFeePercent = parseFloat(
      configMap["gateway_fee_percentage"] ?? "0",
    );

    // Inflar el monto USD para absorber la comisión de PAP
    // Así después de que PAP descuente su %, nos llega plan.price completo
    const amountUsdToSend = plan.price / (1 - gatewayFeePercent / 100);

    // Fallback en VES por si PAP no devuelve monto
    const amountVesFallback = amountUsdToSend * bcvRate;

    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();
    const localOrderId = `MPAY-${Date.now()}-${user.id.substring(0, 8)}`;

    // 2. CREAR ORDEN EN PAGO A PAGO (API EXTERNA)
    const pagoApiKey = Deno.env.get("PAGO_PAGO_API_KEY");
    // ✅ AQUÍ ESTÁ LA MAGIA: Llamamos al Supabase de ELLOS, no al nuestro
    const PAGO_A_PAGO_URL =
      "https://mqlboutjgscjgogqbsjc.supabase.co/functions/v1/api_pay_orders";

    const pagoAPagoPayload = {
      amount: amountUsdToSend,
      currency: "USD",
      email: profile.email,
      phone: profile.phone,
      motive: `Compra de plan: ${plan.name}`,
      dni: profile.dni,
      type_order: "EXTERNAL",
      expires_at: expiresAt,
      alias: localOrderId,
      extra_data: { local_plan_id: plan.id, user_id: user.id, clovers_amount: plan.amount },
    };

    console.log("[api_pay_orders] Solicitando link a Pago a Pago...");

    const pagoResponse = await fetch(PAGO_A_PAGO_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        pago_pago_api: pagoApiKey!, // Pasamos tu clave secreta
      },
      body: JSON.stringify(pagoAPagoPayload),
    });

    if (!pagoResponse.ok) {
      const err = await pagoResponse.text();
      console.error("Error de Pago a Pago:", err);
      throw new Error("No se pudo generar el link de pago con el banco.");
    }

    const pagoData = await pagoResponse.json();

    // Extraemos los datos que nos devolvió Pago a Pago
    const externalOrderId = pagoData.data.order_id;
    const paymentUrl = pagoData.data.payment_url;
    // Monto real en VES que PAP calculó (lo que el usuario debe pagar)
    const amountVesReal = pagoData.data.amount_ves ?? pagoData.data.amount ?? amountVesFallback;

    console.log(`[api_pay_orders] PAP amount_ves: ${amountVesReal}, fallback: ${amountVesFallback}`);

    // 3. GENERAR CÓDIGO DE VALIDACIÓN ÚNICO
    const { data: validationCode, error: codeError } = await supabaseAdmin.rpc(
      "generate_validation_code",
    );
    if (codeError || !validationCode) {
      console.error(
        "[api_pay_orders] Error generando validation_code:",
        codeError,
      );
      throw new Error("No se pudo generar el código de validación");
    }
    console.log("[api_pay_orders] Validation code generado:", validationCode);

    // 4. GUARDAR EN TU BASE DE DATOS LOCAL
    const { data: insertedOrder, error: dbError } = await supabaseAdmin
      .from("clover_orders")
      .insert({
        user_id: user.id,
        plan_id: plan.id,
        amount: plan.price,
        currency: "USD",
        status: "pending",
        pago_pago_order_id: externalOrderId, // Guardamos el ID que nos dio Pago a Pago
        validation_code: validationCode, // Código para validar Pago Móvil
        expires_at: expiresAt,
        extra_data: {
          payment_url: paymentUrl,
          ...pagoAPagoPayload.extra_data,
          amount_ves_total: amountVesReal,
        },
      })
      .select("id, validation_code")
      .single();

    if (dbError) throw new Error("Error guardando orden local");

    // 5. RESPONDER A FLUTTER
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          db_order_id: insertedOrder.id,
          external_order_id: externalOrderId,
          validation_code: insertedOrder.validation_code,
          amount_ves: amountVesReal,
          payment_url: paymentUrl,
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error) {
    console.error("[api_pay_orders] Error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message, success: false }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      },
    );
  }
});

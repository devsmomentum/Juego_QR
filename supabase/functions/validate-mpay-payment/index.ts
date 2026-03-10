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
    // 1. AUTHENTICATE USER via JWT
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

    if (!user) {
      throw new Error("No autorizado");
    }

    // 2. PARSE REQUEST BODY
    const { phone, reference, concept, order_id } = await req.json();

    if (!phone || !reference || !concept || !order_id) {
      throw new Error(
        "Campos requeridos: phone, reference, concept, order_id",
      );
    }

    // Validate reference format (8 digits)
    if (!/^\d{4,8}$/.test(reference)) {
      throw new Error("La referencia debe tener entre 4 y 8 dígitos numéricos");
    }

    console.log(
      `[validate-mpay] User ${user.id} validating order ${order_id}`,
    );

    // 3. INITIALIZE ADMIN CLIENT
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceRoleKey) {
      throw new Error("Server Misconfiguration: Missing service role key");
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceRoleKey,
    );

    // 4. FETCH AND VALIDATE ORDER
    const { data: order, error: orderError } = await supabaseAdmin
      .from("clover_orders")
      .select(
        "id, user_id, status, validation_code, amount, extra_data, plan_id, pago_pago_order_id",
      )
      .eq("id", order_id)
      .single();

    if (orderError || !order) {
      throw new Error("Orden no encontrada");
    }

    // Security: Verify the order belongs to this user
    if (order.user_id !== user.id) {
      throw new Error("No autorizado para validar esta orden");
    }

    // Only pending orders can be validated
    if (order.status !== "pending") {
      throw new Error(
        `Esta orden ya fue procesada (estado: ${order.status})`,
      );
    }

    // Verify concept matches validation_code
    if (
      !order.validation_code ||
      concept.toUpperCase().trim() !== order.validation_code.toUpperCase()
    ) {
      throw new Error(
        "El concepto no coincide con el código de validación de la orden",
      );
    }

    // 5. GET PAGO A PAGO API CONFIG
    const pagoApiKey = Deno.env.get("PAGO_PAGO_API_KEY");
    if (!pagoApiKey) {
      throw new Error("Server Misconfiguration: Missing PAGO_PAGO_API_KEY");
    }

    const PAGO_PAGO_BASE_URL =
      Deno.env.get("PAGO_PAGO_BASE_URL") ??
      "https://app.pagoapago.com/api/v1";

    // 6. CALL PAGO A PAGO validate_mpay_api
    const validateUrl = `${PAGO_PAGO_BASE_URL}/validate_mpay_api`;

    const validatePayload = {
      phone: phone,
      reference: reference,
      concept: concept,
    };

    console.log(
      `[validate-mpay] Calling ${validateUrl} with:`,
      JSON.stringify(validatePayload),
    );

    let apiResponse;

    // MOCK CHECK (For Dev/Test)
    if (
      PAGO_PAGO_BASE_URL.includes("pagoapago.com/v1") ||
      PAGO_PAGO_BASE_URL.includes("mock")
    ) {
      console.log("[validate-mpay] MOCK mode - simulating success");
      apiResponse = {
        success: true,
        message: "Pago verificado exitosamente",
        data: {
          amount: order.extra_data?.amount_ves_total ?? 0,
          status: "verified",
        },
      };
    } else {
      const response = await fetch(validateUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          pago_pago_api: pagoApiKey,
        },
        body: JSON.stringify(validatePayload),
      });

      if (!response.ok) {
        const errText = await response.text();
        console.error(
          `[validate-mpay] API Error (${response.status}):`,
          errText,
        );

        // Record failed attempt
        await supabaseAdmin.from("mpay_validations").insert({
          user_id: user.id,
          order_id: order.id,
          phone,
          reference,
          concept,
          status: "failed",
          api_response: { status: response.status, body: errText },
        });

        throw new Error(
          `Error al validar con la pasarela (${response.status})`,
        );
      }

      apiResponse = await response.json();
      console.log(
        "[validate-mpay] API Response:",
        JSON.stringify(apiResponse),
      );
    }

    // 7. PROCESS RESULT
    if (!apiResponse.success) {
      // Record failed validation attempt
      await supabaseAdmin.from("mpay_validations").insert({
        user_id: user.id,
        order_id: order.id,
        phone,
        reference,
        concept,
        status: "failed",
        api_response: apiResponse,
      });

      return new Response(
        JSON.stringify({
          success: false,
          message:
            apiResponse.message || "No se pudo verificar el pago móvil",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        },
      );
    }

    // 8. PAYMENT VERIFIED — Calculate fee distribution
    const amountRaw =
      apiResponse.data?.amount ??
      order.extra_data?.amount_ves_total ??
      0;
    const feeBank = amountRaw * 0.015; // 1.5% banco
    const feePlatform = amountRaw * 0.005; // 0.5% plataforma
    const amountUser = amountRaw * 0.98; // 98% usuario

    console.log(
      `[validate-mpay] Fee split: raw=${amountRaw}, bank=${feeBank.toFixed(2)}, platform=${feePlatform.toFixed(2)}, user=${amountUser.toFixed(2)}`,
    );

    // 9. UPDATE ORDER STATUS TO 'success'
    // This triggers process_paid_clover_order() which credits clovers automatically
    const { error: updateError } = await supabaseAdmin
      .from("clover_orders")
      .update({
        status: "success",
        transaction_id: reference,
        bank_reference: reference,
        extra_data: {
          ...order.extra_data,
          mpay_validation: {
            phone,
            reference,
            concept,
            amount_raw: amountRaw,
            fee_bank: feeBank,
            fee_platform: feePlatform,
            amount_user: amountUser,
            validated_at: new Date().toISOString(),
            api_response: apiResponse,
          },
          function_version: "v1-mpay",
        },
      })
      .eq("id", order.id);

    if (updateError) {
      console.error("[validate-mpay] DB update error:", updateError);
      throw new Error("Error al actualizar la orden en la base de datos");
    }

    // 10. RECORD SUCCESSFUL VALIDATION IN AUDIT TABLE
    await supabaseAdmin.from("mpay_validations").insert({
      user_id: user.id,
      order_id: order.id,
      phone,
      reference,
      concept,
      status: "success",
      amount_raw: amountRaw,
      fee_bank: feeBank,
      fee_platform: feePlatform,
      amount_user: amountUser,
      api_response: apiResponse,
    });

    console.log(
      `[validate-mpay] Order ${order.id} validated successfully. Clovers will be credited by trigger.`,
    );

    // 11. RETURN SUCCESS
    return new Response(
      JSON.stringify({
        success: true,
        message: "¡Pago verificado exitosamente!",
        data: {
          order_id: order.id,
          clovers_amount: order.extra_data?.clovers_amount ?? 0,
          amount_raw: amountRaw,
          fee_bank: feeBank,
          fee_platform: feePlatform,
          amount_user: amountUser,
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error) {
    console.error("[validate-mpay] Error:", error);
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

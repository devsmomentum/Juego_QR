import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. AUTHENTICATE USER via JWT
    const authHeader = req.headers.get("Authorization");
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader! } } },
    );

    const { data: { user } } = await supabaseClient.auth.getUser();

    if (!user) {
      throw new Error("No autorizado");
    }

    // 2. PARSE REQUEST BODY
    const { phone: rawPhone, reference, concept, order_id } = await req.json();

    if (!rawPhone || !reference || !concept || !order_id) {
      throw new Error("Campos requeridos: phone, reference, concept, order_id");
    }

    // Limpiar el teléfono
    let phone = String(rawPhone).trim();
    if (phone.startsWith("+58")) phone = "0" + phone.substring(3);
    else if (phone.startsWith("58") && phone.length >= 12) phone = "0" + phone.substring(2);
    phone = phone.replace(/[^0-9]/g, "");

    // Validar referencia
    if (!/^\d{4,8}$/.test(reference)) {
      throw new Error("La referencia debe tener entre 4 y 8 dígitos numéricos");
    }

    // 3. ADMIN CLIENT
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const supabaseAdmin = createClient(Deno.env.get("SUPABASE_URL") ?? "", serviceRoleKey!);

    // 4. VALIDAR LA ORDEN LOCALMENTE
    const { data: order, error: orderError } = await supabaseAdmin
      .from("clover_orders")
      .select("id, user_id, status, validation_code, amount, extra_data")
      .eq("pago_pago_order_id", order_id)
      .single();

    if (orderError || !order) throw new Error("Orden no encontrada");
    if (order.user_id !== user.id) throw new Error("No autorizado para validar esta orden");
    if (order.status !== "pending") throw new Error(`Esta orden ya fue procesada (estado: ${order.status})`);

    // 5. CONFIGURAR CONEXIÓN A PAGO A PAGO
    const pagoApiKey = Deno.env.get("PAGO_PAGO_API_KEY");
    if (!pagoApiKey) throw new Error("Missing PAGO_PAGO_API_KEY");

    const validateUrl = "https://mqlboutjgscjgogqbsjc.supabase.co/functions/v1/validate_mpay_api_v2";

    const validatePayload = {
      phone: phone,
      reference: reference,
      concept: concept,
      order_id: order_id,
    };

    // 6. HACER LA PETICIÓN EXTERNA
    const response = await fetch(validateUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "pago_pago_api": pagoApiKey,
      },
      body: JSON.stringify(validatePayload),
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Error de conexión con la pasarela (${response.status}): ${errText}`);
    }

    // 7. PROCESAR RESPUESTA DE LA PASARELA
    const apiResponse = await response.json();

    // === CASO A: Pago ya procesado (duplicado/reclamado) ===
    if (apiResponse.success === false && apiResponse.claimed === true) {
      await supabaseAdmin.from("mpay_validations").insert({
        user_id: user.id, order_id: order.id, phone, reference, concept,
        status: "already_claimed", api_response: apiResponse,
      });

      return new Response(
        JSON.stringify({
          success: false,
          claimed: true,
          message: apiResponse.message || "Este pago ya fue procesado y reclamado anteriormente",
          reference: apiResponse.reference ?? reference,
          amount: apiResponse.amount ?? null,
          montoUsuario: apiResponse.montoUsuario ?? null,
          order_status: apiResponse.order_status ?? "completed",
          order_id: apiResponse.order_id ?? null,
          payment_id: apiResponse.payment_id ?? null,
          userId: user.id,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // === CASO B: Pago no encontrado ===
    if (apiResponse.success === false && !apiResponse.claimed) {
      await supabaseAdmin.from("mpay_validations").insert({
        user_id: user.id, order_id: order.id, phone, reference, concept,
        status: "not_found", api_response: apiResponse,
      });

      return new Response(
        JSON.stringify({
          success: false,
          claimed: false,
          message: apiResponse.message || "No se encontró pago móvil con esos datos",
          reference: apiResponse.reference ?? null,
          amount: apiResponse.amount ?? null,
          montoUsuario: apiResponse.montoUsuario ?? null,
          order_status: apiResponse.order_status ?? null,
          order_id: apiResponse.order_id ?? null,
          payment_id: apiResponse.payment_id ?? null,
          searchParams: {
            phone: phone,
            reference: reference,
            concept: concept || null,
          },
          userId: user.id,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // === CASO C: Pago encontrado pero no procesado aún ===
    if (apiResponse.success === true && apiResponse.claimed === false) {
      await supabaseAdmin.from("mpay_validations").insert({
        user_id: user.id, order_id: order.id, phone, reference, concept,
        status: "found_not_processed", api_response: apiResponse,
      });

      // NO actualizamos la orden — el pago aún no fue reclamado
      return new Response(
        JSON.stringify({
          success: true,
          claimed: false,
          message: apiResponse.message || "Pago móvil encontrado pero no procesado",
          reference: apiResponse.reference ?? null,
          amount: apiResponse.amount ?? null,
          montoUsuario: apiResponse.montoUsuario ?? null,
          order_status: apiResponse.order_status ?? null,
          order_id: apiResponse.order_id ?? null,
          payment_id: apiResponse.payment_id ?? null,
          userId: user.id,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // === CASO D: Procesamiento Exitoso (success: true, claimed: true) ===
    const amountRaw = apiResponse.amount ?? order.extra_data?.amount_ves_total ?? 0;
    const amountUser = apiResponse.montoUsuario ?? amountRaw * 0.98;
    const feeTotal = amountRaw - amountUser;
    const orderStatus = apiResponse.order_status ?? "paid";

    // Solo acreditamos tréboles si la orden fue pagada en su totalidad
    const shouldCreditClovers = orderStatus === "paid";

    if (shouldCreditClovers) {
      // ACTUALIZAR BASE DE DATOS LOCAL → dispara trigger de tréboles
      const updateOrderPromise = supabaseAdmin
        .from("clover_orders")
        .update({
          status: "success",
          transaction_id: apiResponse.reference ?? reference,
          bank_reference: apiResponse.reference ?? reference,
          extra_data: {
            ...order.extra_data,
            mpay_validation: {
              phone, reference, concept, amount_raw: amountRaw, amount_user: amountUser,
              fee_total: feeTotal, validated_at: new Date().toISOString(), api_response: apiResponse,
            },
          },
        })
        .eq("id", order.id);

      const insertAuditPromise = supabaseAdmin.from("mpay_validations").insert({
        user_id: user.id, order_id: order.id, phone, reference, concept,
        status: "success", amount_raw: amountRaw, amount_user: amountUser,
        fee_total: feeTotal, api_response: apiResponse,
      });

      const [updateResult] = await Promise.all([updateOrderPromise, insertAuditPromise]);

      if (updateResult.error) {
        throw new Error("El pago se verificó pero hubo un error actualizando la orden local");
      }
    } else {
      // Orden cancelada: registrar auditoría sin acreditar tréboles
      await supabaseAdmin.from("mpay_validations").insert({
        user_id: user.id, order_id: order.id, phone, reference, concept,
        status: "order_cancelled", amount_raw: amountRaw, amount_user: amountUser,
        fee_total: feeTotal, api_response: apiResponse,
      });
    }

    return new Response(
      JSON.stringify({
        success: shouldCreditClovers,
        claimed: true,
        message: apiResponse.message || (shouldCreditClovers
          ? "Pago procesado satisfactoriamente"
          : "Pago procesado pero la orden fue cancelada"),
        reference: apiResponse.reference ?? reference,
        amount: amountRaw,
        montoUsuario: amountUser,
        order_status: orderStatus,
        order_id: apiResponse.order_id ?? null,
        payment_id: apiResponse.payment_id ?? null,
        userId: user.id,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );

  } catch (error) {
    console.error("[validate-mpay] Error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
    );
  }
});
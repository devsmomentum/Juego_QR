import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.25.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/**
 * Retrieves the client_secret for an existing pending Stripe order
 * so the user can re-present the Payment Sheet and complete the payment.
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. AUTHENTICATE USER
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceRoleKey) {
      throw new Error("Server Misconfiguration: Missing SUPABASE_SERVICE_ROLE_KEY");
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "No authorization header", success: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Sesión inválida o expirada", success: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    // 2. PARSE REQUEST
    const { order_id } = await req.json();
    if (!order_id) {
      return new Response(
        JSON.stringify({ error: "Missing order_id", success: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    console.log(`[stripe-resume] User ${user.id} resuming order ${order_id}`);

    // 3. FETCH ORDER & VERIFY OWNERSHIP
    const { data: order, error: orderError } = await supabaseAdmin
      .from("clover_orders")
      .select("id, user_id, status, gateway, stripe_payment_intent_id, extra_data, expires_at, plan_id")
      .eq("id", order_id)
      .single();

    if (orderError || !order) {
      throw new Error("Orden no encontrada");
    }

    if (order.user_id !== user.id) {
      throw new Error("No autorizado");
    }

    if (order.gateway !== "stripe") {
      throw new Error("Esta orden no es de Stripe");
    }

    if (order.status !== "pending") {
      throw new Error(`No se puede retomar una orden con estado: ${order.status}`);
    }

    // Check expiration
    if (order.expires_at && new Date(order.expires_at) < new Date()) {
      throw new Error("Esta orden ha expirado. Por favor crea una nueva compra.");
    }

    const stripeRef = order.stripe_payment_intent_id;
    if (!stripeRef) {
      throw new Error("Orden sin referencia de pago asociada");
    }

    // 4. RETRIEVE FROM STRIPE
    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      throw new Error("Server Misconfiguration: Missing STRIPE_SECRET_KEY");
    }

    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: "2024-06-20",
      httpClient: Stripe.createFetchHttpClient(),
    });

    const isCheckoutSession = stripeRef.startsWith("cs_");
    let paymentIntentId = "";
    let clientSecret = "";
    let checkoutUrl = "";

    if (isCheckoutSession) {
      // --- CHECKOUT SESSION (Web orders) ---
      const session = await stripe.checkout.sessions.retrieve(stripeRef);

      if (session.status === "complete") {
        await supabaseAdmin
          .from("clover_orders")
          .update({ status: "success", updated_at: new Date().toISOString() })
          .eq("id", order_id);
        throw new Error("Este pago ya fue completado. Tus tréboles serán acreditados.");
      }

      if (session.status === "expired") {
        await supabaseAdmin
          .from("clover_orders")
          .update({ status: "expired", updated_at: new Date().toISOString() })
          .eq("id", order_id);
        throw new Error("Esta sesión de pago expiró. Por favor crea una nueva compra.");
      }

      // Session is still open — return the checkout URL so the user can complete it
      if (session.url) {
        checkoutUrl = session.url;
      } else {
        throw new Error("No se pudo recuperar la URL de pago. Por favor crea una nueva compra.");
      }

      // If session has a payment_intent, also provide it
      if (session.payment_intent) {
        paymentIntentId = session.payment_intent as string;
      }
    } else {
      // --- PAYMENT INTENT (Mobile orders) ---
      const paymentIntent = await stripe.paymentIntents.retrieve(stripeRef);
      paymentIntentId = stripeRef;

      if (paymentIntent.status === "succeeded") {
        await supabaseAdmin
          .from("clover_orders")
          .update({ status: "success", updated_at: new Date().toISOString() })
          .eq("id", order_id);
        throw new Error("Este pago ya fue completado. Tus tréboles serán acreditados.");
      }

      if (paymentIntent.status === "canceled") {
        await supabaseAdmin
          .from("clover_orders")
          .update({ status: "cancelled", updated_at: new Date().toISOString() })
          .eq("id", order_id);
        throw new Error("Este pago fue cancelado. Por favor crea una nueva compra.");
      }

      const resumableStatuses = ["requires_payment_method", "requires_confirmation", "requires_action"];
      if (!resumableStatuses.includes(paymentIntent.status)) {
        throw new Error(`Estado del pago no permite reintentar: ${paymentIntent.status}`);
      }

      clientSecret = paymentIntent.client_secret!;
    }

    // 5. GET CUSTOMER DATA FOR PAYMENT SHEET
    let stripeCustomerId = "";
    let ephemeralKeySecret = "";

    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("stripe_customer_id")
      .eq("id", user.id)
      .maybeSingle();

    stripeCustomerId = profile?.stripe_customer_id ?? "";

    if (stripeCustomerId) {
      try {
        const ephemeralKey = await stripe.ephemeralKeys.create(
          { customer: stripeCustomerId },
          { apiVersion: "2024-06-20" }
        );
        ephemeralKeySecret = ephemeralKey.secret!;
      } catch (ekErr: any) {
        console.warn(`[stripe-resume] Could not create ephemeral key: ${ekErr.message}`);
      }
    }

    const extraData = order.extra_data ?? {};

    console.log(`[stripe-resume] Ref ${stripeRef}, isCheckout: ${isCheckoutSession}, resumable.`);

    // 6. RETURN CLIENT SECRET OR CHECKOUT URL
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          client_secret: clientSecret || null,
          payment_intent_id: paymentIntentId || null,
          checkout_url: checkoutUrl || null,
          is_checkout_session: isCheckoutSession,
          stripe_customer_id: stripeCustomerId || null,
          ephemeral_key_secret: ephemeralKeySecret || null,
          clovers: extraData.clovers_amount ?? 0,
          plan_name: extraData.plan_name ?? "",
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error: any) {
    console.error("[stripe-resume] Error:", error);
    return new Response(
      JSON.stringify({ error: error.message, success: false }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});

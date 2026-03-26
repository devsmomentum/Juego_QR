import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.25.0?target=deno";

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
    // 1. AUTHENTICATE — only admins can call this
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(JSON.stringify({ error: "No authorization header", success: false }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey);
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized", success: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    // Verify user is admin
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
      global: {
        headers: {
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      },
    });

    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (!profile || profile.role !== "admin") {
      return new Response(
        JSON.stringify({ error: "Forbidden: admin only", success: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 403 }
      );
    }

    // 2. GET ORDER FROM DB
    const { clover_order_id } = await req.json();

    if (!clover_order_id) {
      return new Response(
        JSON.stringify({ error: "Missing clover_order_id", success: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const { data: order, error: orderError } = await supabaseAdmin
      .from("clover_orders")
      .select("id, status, user_id, extra_data, stripe_payment_intent_id")
      .eq("id", clover_order_id)
      .eq("gateway", "stripe")
      .single();

    if (orderError || !order) {
      return new Response(
        JSON.stringify({ error: "Order not found", success: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 404 }
      );
    }

    // Already processed — avoid double crediting
    if (order.status === "success" || order.status === "completed") {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Esta orden ya fue procesada anteriormente.",
          order_status: order.status,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 409 }
      );
    }

    const paymentIntentId = order.stripe_payment_intent_id;
    if (!paymentIntentId || !paymentIntentId.startsWith("pi_")) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Esta orden no tiene un PaymentIntent de Stripe válido. No se puede verificar.",
          stripe_status: null,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 422 }
      );
    }

    // 3. VERIFY WITH STRIPE API
    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")!;
    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: "2024-06-20",
      httpClient: Stripe.createFetchHttpClient(),
    });

    let paymentIntent: Stripe.PaymentIntent;
    try {
      paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    } catch (stripeErr: unknown) {
      const msg = stripeErr instanceof Error ? stripeErr.message : String(stripeErr);
      return new Response(
        JSON.stringify({
          success: false,
          error: `Error al consultar Stripe: ${msg}`,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 502 }
      );
    }

    console.log(`[stripe-verify-and-credit] PI ${paymentIntentId} status: ${paymentIntent.status}`);

    // 4. ONLY CREDIT IF STRIPE CONFIRMS PAYMENT
    if (paymentIntent.status !== "succeeded") {
      return new Response(
        JSON.stringify({
          success: false,
          error: `El pago NO está confirmado en Stripe. Estado actual: "${paymentIntent.status}". Solo se acreditan órdenes con estado "succeeded".`,
          stripe_status: paymentIntent.status,
          stripe_pi_id: paymentIntentId,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 422 }
      );
    }

    // 5. MARK ORDER AS SUCCESS (triggers DB trigger that credits clovers)
    const { error: updateError } = await supabaseAdmin
      .from("clover_orders")
      .update({
        status: "success",
        extra_data: {
          ...(order.extra_data || {}),
          completed_at: new Date().toISOString(),
          manual_fix: true,
          fixed_by_admin: user.id,
          stripe_verified: true,
          stripe_pi_status: "succeeded",
          stripe_amount: paymentIntent.amount,
        },
      })
      .eq("id", clover_order_id);

    if (updateError) {
      return new Response(
        JSON.stringify({ success: false, error: `DB error: ${updateError.message}` }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    const cloversAmount = parseInt(order.extra_data?.clovers_amount ?? "0", 10);

    console.log(`[stripe-verify-and-credit] ✅ Order ${clover_order_id} credited. Clovers: ${cloversAmount}, User: ${order.user_id}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `✅ Verificado en Stripe y acreditados ${cloversAmount} tréboles al usuario.`,
        stripe_status: "succeeded",
        clovers_credited: cloversAmount,
        user_id: order.user_id,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );

  } catch (error) {
    console.error("[stripe-verify-and-credit] Error:", error);
    return new Response(
      JSON.stringify({ error: error.message, success: false }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});

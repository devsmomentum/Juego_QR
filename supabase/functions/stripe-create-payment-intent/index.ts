import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

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
    // 1. AUTHENTICATE USER
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    const {
      data: { user },
    } = await supabaseClient.auth.getUser();

    if (!user) {
      return new Response(JSON.stringify({ error: "Unauthorized", success: false }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    // 2. PARSE REQUEST — only plan_id from client (price validated server-side)
    const { plan_id } = await req.json();

    if (!plan_id) {
      return new Response(
        JSON.stringify({ error: "Missing plan_id", success: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    console.log(`[stripe-create-pi] User: ${user.id}, Plan: ${plan_id}`);

    // 3. ADMIN CLIENT
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceRoleKey) {
      throw new Error("Server Misconfiguration: Missing SUPABASE_SERVICE_ROLE_KEY");
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceRoleKey
    );

    // 4. VALIDATE PLAN FROM DATABASE (price always from DB — security)
    const { data: plan, error: planError } = await supabaseAdmin
      .from("transaction_plans")
      .select("id, name, amount, price, is_active, type")
      .eq("id", plan_id)
      .eq("type", "buy")
      .single();

    if (planError || !plan) {
      throw new Error(`Plan inválido o no encontrado: ${planError?.message}`);
    }

    if (!plan.is_active) {
      throw new Error("El plan seleccionado no está disponible");
    }

    const amountUsd = plan.price as number;         // e.g. 4.99
    const cloversQuantity = plan.amount as number;  // e.g. 150
    // Stripe requires amount in cents (smallest currency unit)
    const amountCents = Math.round(amountUsd * 100);

    console.log(`[stripe-create-pi] Plan: ${plan.name}, $${amountUsd} USD (${amountCents} cents), ${cloversQuantity} tréboles`);

    // 5. GET STRIPE SECRET KEY
    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      throw new Error("Server Misconfiguration: Missing STRIPE_SECRET_KEY");
    }

    // 6. CREATE STRIPE PAYMENT INTENT
    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: "2024-06-20",
      httpClient: Stripe.createFetchHttpClient(),
    });

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: "usd",
      description: `Compra de ${cloversQuantity} Tréboles - Plan ${plan.name}`,
      metadata: {
        user_id: user.id,
        plan_id: plan.id,
        plan_name: plan.name,
        clovers_amount: String(cloversQuantity),
      },
      // Allows saving the payment method for future use (optional)
      // automatic_payment_methods: { enabled: true },
      payment_method_types: ["card"],
    });

    console.log(`[stripe-create-pi] Created PaymentIntent: ${paymentIntent.id}`);

    // 7. PERSIST ORDER IN DATABASE
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();

    const { error: dbError } = await supabaseAdmin
      .from("clover_orders")
      .insert({
        user_id: user.id,
        plan_id: plan.id,
        amount: amountUsd,
        currency: "USD",
        status: "pending",
        gateway: "stripe",
        stripe_payment_intent_id: paymentIntent.id,
        expires_at: expiresAt,
        extra_data: {
          plan_name: plan.name,
          clovers_amount: cloversQuantity,
          price_usd: amountUsd,
          initiated_at: new Date().toISOString(),
          function_version: "stripe-v1",
        },
      });

    if (dbError) {
      console.error("[stripe-create-pi] DB Error:", dbError);
      // Cancel the PaymentIntent if DB insert fails to avoid orphaned intents
      await stripe.paymentIntents.cancel(paymentIntent.id).catch(console.error);
      throw new Error(`Database error: ${dbError.message}`);
    }

    console.log("[stripe-create-pi] Order persisted successfully.");

    // 8. RETURN CLIENT SECRET TO APP
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          client_secret: paymentIntent.client_secret,
          payment_intent_id: paymentIntent.id,
          amount_cents: amountCents,
          amount_usd: amountUsd,
          clovers: cloversQuantity,
          plan: {
            id: plan.id,
            name: plan.name,
          },
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("[stripe-create-pi] Error:", error);
    return new Response(
      JSON.stringify({ error: error.message, success: false }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});

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
    // 1. AUTHENTICATE USER
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
      console.error("[stripe-create-pi] Auth Error:", authError);
      return new Response(
        JSON.stringify({ 
          error: "Sesión inválida o expirada. Por favor, logueate de nuevo.", 
          details: authError?.message,
          success: false 
        }), 
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    // 2. PARSE REQUEST
    const { plan_id, is_web, success_url, cancel_url, save_card } = await req.json();

    if (!plan_id) {
      return new Response(
        JSON.stringify({ error: "Missing plan_id", success: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const shouldSaveCard = save_card === true;
    console.log(`[stripe-create-pi] User: ${user.id}, Plan: ${plan_id}, SaveCard: ${shouldSaveCard}`);

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
    const amountCents = Math.round(amountUsd * 100);

    console.log(`[stripe-create-pi] Plan: ${plan.name}, $${amountUsd} USD (${amountCents} cents), ${cloversQuantity} tréboles`);

    // 5. GET STRIPE SECRET KEY
    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      throw new Error("Server Misconfiguration: Missing STRIPE_SECRET_KEY");
    }

    const internalOrderId = crypto.randomUUID();
    let paymentIntentId = "";
    let clientSecret = "";
    let checkoutUrl = "";
    let ephemeralKeySecret = "";
    let stripeCustomerId = "";
    let newCustomerCreated = false;

    // 6. INITIALIZE STRIPE
    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: "2024-06-20",
      httpClient: Stripe.createFetchHttpClient(),
    });

    if (is_web) {
      // 6a. CREATE STRIPE CHECKOUT SESSION (Web)
      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        line_items: [
          {
            price_data: {
              currency: "usd",
              product_data: {
                name: `Compra de ${cloversQuantity} Tréboles - Plan ${plan.name}`,
                description: plan.name,
              },
              unit_amount: amountCents,
            },
            quantity: 1,
          },
        ],
        mode: "payment",
        success_url: success_url || `${supabaseUrl}/auth/v1/verify`,
        cancel_url: cancel_url || success_url,
        metadata: {
          user_id: user.id,
          plan_id: plan.id,
          plan_name: plan.name,
          clovers_amount: String(cloversQuantity),
          clover_order_id: internalOrderId,
        },
        payment_intent_data: {
          metadata: {
            user_id: user.id,
            plan_id: plan.id,
            plan_name: plan.name,
            clovers_amount: String(cloversQuantity),
            clover_order_id: internalOrderId,
          },
        },
      });
      checkoutUrl = session.url!;
      paymentIntentId = session.payment_intent as string || session.id; 
    } else {
      // 6b. CREATE STRIPE PAYMENT INTENT (Mobile)
      
      // --- STRIPE CUSTOMER LOGIC ---
      // Get the user's existing stripe_customer_id from their profile
      const { data: profile } = await supabaseAdmin
        .from("profiles")
        .select("stripe_customer_id")
        .eq("id", user.id)
        .single();

      stripeCustomerId = profile?.stripe_customer_id ?? "";

      // If saving card and no customer exists yet, create one
      if (!stripeCustomerId) {
        // Always create a customer when saving a card, so we can retrieve their payment methods later
        // Also create for non-save to allow future use if user changes their mind
        const customer = await stripe.customers.create({
          metadata: { supabase_user_id: user.id },
          email: user.email ?? undefined,
        });
        stripeCustomerId = customer.id;
        newCustomerCreated = true;

        // Persist the customer ID immediately
        await supabaseAdmin
          .from("profiles")
          .update({ stripe_customer_id: stripeCustomerId })
          .eq("id", user.id);

        console.log(`[stripe-create-pi] Created Stripe Customer: ${stripeCustomerId}`);
      }

      // Generate an Ephemeral Key so Flutter can authenticate with Stripe
      const ephemeralKey = await stripe.ephemeralKeys.create(
        { customer: stripeCustomerId },
        { apiVersion: "2024-06-20" }
      );
      ephemeralKeySecret = ephemeralKey.secret!;

      // Build PaymentIntent options
      // NOTE: allow_redirects: 'never' ensures only instant-completion methods (card)
      // are available, preventing the payment from getting stuck in 'processing' state
      // due to bank redirects (iDEAL, SEPA, Boleto, etc.)
      const paymentIntentParams: Stripe.PaymentIntentCreateParams = {
        amount: amountCents,
        currency: "usd",
        customer: stripeCustomerId,
        description: `Compra de ${cloversQuantity} Tréboles - Plan ${plan.name}`,
        metadata: {
          user_id: user.id,
          plan_id: plan.id,
          plan_name: plan.name,
          clovers_amount: String(cloversQuantity),
          clover_order_id: internalOrderId,
        },
        // KEY FIX: allow_redirects: 'never' prevents redirect-based payment methods
        // that would leave the PaymentIntent in 'requires_action' or 'processing' state.
        // This guarantees the PI goes directly to 'succeeded' when using a card.
        automatic_payment_methods: { 
          enabled: true,
          allow_redirects: "never",
        },
      };

      // If user wants to save the card, use setup_future_usage
      if (shouldSaveCard) {
        paymentIntentParams.setup_future_usage = "off_session";
        console.log(`[stripe-create-pi] Card will be saved for future use (off_session)`);
      }

      const paymentIntent = await stripe.paymentIntents.create(paymentIntentParams);
      paymentIntentId = paymentIntent.id;
      clientSecret = paymentIntent.client_secret!;

      console.log(`[stripe-create-pi] Created PaymentIntent: ${paymentIntentId}, AllowRedirects: never`);
    }

    // 7. PERSIST ORDER IN DATABASE
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();

    const { error: dbError } = await supabaseAdmin
      .from("clover_orders")
      .insert({
        id: internalOrderId,
        user_id: user.id,
        plan_id: plan.id,
        amount: amountUsd,
        currency: "USD",
        status: "pending",
        gateway: "stripe",
        stripe_payment_intent_id: paymentIntentId || null,
        expires_at: expiresAt,
        extra_data: {
          plan_name: plan.name,
          clovers_amount: cloversQuantity,
          price_usd: amountUsd,
          initiated_at: new Date().toISOString(),
          function_version: "stripe-v3-customer-support",
          is_web: !!is_web,
          save_card: shouldSaveCard,
          stripe_customer_id: stripeCustomerId || null,
        },
      });

    if (dbError) {
      console.error("[stripe-create-pi] DB Error:", dbError);
      throw new Error(`Database error: ${dbError.message}`);
    }

    console.log("[stripe-create-pi] Order persisted successfully.");

    // 8. RETURN CLIENT SECRET TO APP
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          client_secret: clientSecret,
          payment_intent_id: paymentIntentId,
          checkout_url: checkoutUrl,
          amount_cents: amountCents,
          amount_usd: amountUsd,
          clovers: cloversQuantity,
          // Customer data for Flutter Payment Sheet
          stripe_customer_id: stripeCustomerId || null,
          ephemeral_key_secret: ephemeralKeySecret || null,
          new_customer_created: newCustomerCreated,
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

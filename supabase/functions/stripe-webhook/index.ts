import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

// Stripe webhooks do NOT use CORS — they are server-to-server calls
serve(async (req) => {
  try {
    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");

    if (!stripeSecretKey || !webhookSecret) {
      console.error("[stripe-webhook] Missing STRIPE_SECRET_KEY or STRIPE_WEBHOOK_SECRET");
      return new Response("Server Misconfiguration", { status: 500 });
    }

    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: "2024-06-20",
      httpClient: Stripe.createFetchHttpClient(),
    });

    // 1. VERIFY STRIPE SIGNATURE (security — ensures request is from Stripe)
    const signature = req.headers.get("stripe-signature");
    if (!signature) {
      console.error("[stripe-webhook] Missing stripe-signature header");
      return new Response("Missing signature", { status: 400 });
    }

    const rawBody = await req.text();
    let event: Stripe.Event;

    try {
      event = await stripe.webhooks.constructEventAsync(
        rawBody,
        signature,
        webhookSecret
      );
    } catch (err) {
      console.error("[stripe-webhook] Signature verification failed:", err.message);
      return new Response(`Webhook Error: ${err.message}`, { status: 400 });
    }

    console.log(`[stripe-webhook] Event received: ${event.type}, ID: ${event.id}`);

    // 2. ADMIN CLIENT (for DB operations — bypasses RLS)
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceRoleKey) {
      console.error("[stripe-webhook] Missing SUPABASE_SERVICE_ROLE_KEY");
      return new Response("Server Misconfiguration", { status: 500 });
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceRoleKey
    );

    // 3. UNIFY ORDER FETCHING (for payment_intent events)
    let existingOrder: any = null;
    const paymentIntent = event.data.object as Stripe.PaymentIntent;
    
    if (event.type.startsWith("payment_intent.")) {
      const { data: order } = await supabaseAdmin
        .from("clover_orders")
        .select("id, status, extra_data")
        .eq("stripe_payment_intent_id", paymentIntent.id)
        .maybeSingle();
      existingOrder = order;
    }

    // 4. HANDLE EVENTS
    switch (event.type) {
      case "payment_intent.succeeded": {
        const paymentIntentId = paymentIntent.id;
        const userId = paymentIntent.metadata?.user_id;
        const cloversAmount = parseInt(paymentIntent.metadata?.clovers_amount ?? "0", 10);

        console.log(`[stripe-webhook] payment_intent.succeeded: ${paymentIntentId}, user: ${userId}, clovers: ${cloversAmount}`);

        if (!userId || !cloversAmount) {
          console.error("[stripe-webhook] Missing user_id or clovers_amount in metadata");
          break;
        }

        if (!existingOrder) {
          console.error(`[stripe-webhook] No order found for PaymentIntent: ${paymentIntentId}`);
          break;
        }

        if (existingOrder.status === "completed" || existingOrder.status === "success") {
          console.log(`[stripe-webhook] Order already processed — skipping. Order: ${existingOrder.id}`);
          break;
        }

        // Update order status to 'success' to trigger the existing DB logic
        const { error: orderError } = await supabaseAdmin
          .from("clover_orders")
          .update({
            status: "success",
            extra_data: {
              ...(existingOrder.extra_data || {}),
              clovers_amount: cloversAmount, // Essential for the trigger 'tr_on_clover_order_paid'
              stripe_event_id: event.id,
              completed_at: new Date().toISOString(),
              payment_method_type: paymentIntent.payment_method_types?.[0],
            },
          })
          .eq("stripe_payment_intent_id", paymentIntentId);

        if (orderError) {
          console.error("[stripe-webhook] Error updating order:", orderError);
          return new Response("DB Error", { status: 500 });
        }

        console.log(`[stripe-webhook] ✅ Success: Order marked as success. Trigger will handle clover increment for user ${userId}`);
        break;
      }

      case "payment_intent.payment_failed": {
        const paymentIntentId = paymentIntent.id;
        const failureMessage = paymentIntent.last_payment_error?.message ?? "Unknown error";

        console.log(`[stripe-webhook] payment_intent.payment_failed: ${paymentIntentId}, reason: ${failureMessage}`);

        if (!existingOrder) {
          console.error(`[stripe-webhook] No order found to mark as failed: ${paymentIntentId}`);
          break;
        }

        const { error } = await supabaseAdmin
          .from("clover_orders")
          .update({
            status: "error",
            extra_data: {
              ...(existingOrder.extra_data || {}),
              failed_at: new Date().toISOString(),
              failure_reason: failureMessage,
              stripe_event_id: event.id,
            },
          })
          .eq("stripe_payment_intent_id", paymentIntentId);

        if (error) {
          console.error("[stripe-webhook] Error marking order as failed:", error);
        }

        console.log(`[stripe-webhook] Order marked as failed for PaymentIntent: ${paymentIntentId}`);
        break;
      }

      case "payment_intent.canceled": {
        console.log(`[stripe-webhook] PaymentIntent canceled: ${paymentIntent.id}`);

        await supabaseAdmin
          .from("clover_orders")
          .update({ status: "cancelled" }) 
          .eq("stripe_payment_intent_id", paymentIntent.id);
        break;
      }

      default:
        console.log(`[stripe-webhook] Unhandled event type: ${event.type}`);
    }

    // Always return 200 to Stripe to acknowledge receipt
    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("[stripe-webhook] Unhandled error:", error);
    return new Response(`Webhook handler error: ${error.message}`, { status: 500 });
  }
});

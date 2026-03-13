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

    // 3. HANDLE EVENTS
    switch (event.type) {
      case "payment_intent.succeeded": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        const paymentIntentId = paymentIntent.id;
        const userId = paymentIntent.metadata?.user_id;
        const cloversAmount = parseInt(paymentIntent.metadata?.clovers_amount ?? "0", 10);

        console.log(`[stripe-webhook] payment_intent.succeeded: ${paymentIntentId}, user: ${userId}, clovers: ${cloversAmount}`);

        if (!userId || !cloversAmount) {
          console.error("[stripe-webhook] Missing user_id or clovers_amount in metadata");
          break;
        }

        // Check if already processed (idempotency)
        const { data: existingOrder } = await supabaseAdmin
          .from("clover_orders")
          .select("id, status")
          .eq("stripe_payment_intent_id", paymentIntentId)
          .single();

        if (!existingOrder) {
          console.error(`[stripe-webhook] No order found for PaymentIntent: ${paymentIntentId}`);
          break;
        }

        if (existingOrder.status === "completed") {
          console.log(`[stripe-webhook] Order already completed — skipping (idempotent). Order: ${existingOrder.id}`);
          break;
        }

        // Update order status
        const { error: orderError } = await supabaseAdmin
          .from("clover_orders")
          .update({
            status: "completed",
            extra_data: {
              completed_at: new Date().toISOString(),
              stripe_event_id: event.id,
            },
          })
          .eq("stripe_payment_intent_id", paymentIntentId);

        if (orderError) {
          console.error("[stripe-webhook] Error updating order:", orderError);
          return new Response("DB Error", { status: 500 });
        }

        // Credit tréboles to user profile
        // Using RPC to atomically increment clovers
        const { error: rpcError } = await supabaseAdmin.rpc("increment_clovers", {
          p_user_id: userId,
          p_amount: cloversAmount,
        });

        if (rpcError) {
          console.error("[stripe-webhook] Error crediting clovers via RPC:", rpcError);
          // Fallback: manual increment
          const { data: profile } = await supabaseAdmin
            .from("profiles")
            .select("clovers")
            .eq("id", userId)
            .single();

          const newClovers = (profile?.clovers ?? 0) + cloversAmount;

          const { error: updateError } = await supabaseAdmin
            .from("profiles")
            .update({ clovers: newClovers })
            .eq("id", userId);

          if (updateError) {
            console.error("[stripe-webhook] CRITICAL: Failed to credit clovers:", updateError);
            return new Response("DB Error crediting clovers", { status: 500 });
          }
        }

        console.log(`[stripe-webhook] ✅ Success: Credited ${cloversAmount} tréboles to user ${userId}`);
        break;
      }

      case "payment_intent.payment_failed": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        const paymentIntentId = paymentIntent.id;
        const failureMessage = paymentIntent.last_payment_error?.message ?? "Unknown error";

        console.log(`[stripe-webhook] payment_intent.payment_failed: ${paymentIntentId}, reason: ${failureMessage}`);

        const { error } = await supabaseAdmin
          .from("clover_orders")
          .update({
            status: "failed",
            extra_data: {
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
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        console.log(`[stripe-webhook] PaymentIntent canceled: ${paymentIntent.id}`);

        await supabaseAdmin
          .from("clover_orders")
          .update({ status: "failed" })
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

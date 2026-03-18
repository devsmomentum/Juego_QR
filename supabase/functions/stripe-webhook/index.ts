import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.25.0?target=deno";

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
      // Use SubtleCryptoProvider for Deno compatibility
      const cryptoProvider = Stripe.createSubtleCryptoProvider();
      event = await stripe.webhooks.constructEventAsync(
        rawBody,
        signature,
        webhookSecret,
        undefined,
        cryptoProvider
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

    // 3. UNIFY ORDER FETCHING
    let existingOrder: any = null;
    let paymentIntentId = "";
    let sessionId = "";
    let checkoutMetadata: any = null;

    if (event.type.startsWith("payment_intent.")) {
      const paymentIntent = event.data.object as Stripe.PaymentIntent;
      paymentIntentId = paymentIntent.id;
      checkoutMetadata = paymentIntent.metadata;
    } else if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;
      paymentIntentId = session.payment_intent as string;
      sessionId = session.id;
      checkoutMetadata = session.metadata;
    }

    const cloverOrderId = checkoutMetadata?.clover_order_id;

    if (cloverOrderId) {
       console.log(`[stripe-webhook] Finding order by internal ID: ${cloverOrderId}`);
       const { data: order } = await supabaseAdmin
         .from("clover_orders")
         .select("id, status, extra_data, user_id")
         .eq("id", cloverOrderId)
         .maybeSingle();
       existingOrder = order;
    }

    if (!existingOrder && (paymentIntentId || sessionId)) {
      console.log(`[stripe-webhook] Falling back to search by PI/Session ID: ${paymentIntentId || sessionId}`);
      // Use logical OR to find by either PI or Session ID
      let query = supabaseAdmin
        .from("clover_orders")
        .select("id, status, extra_data, user_id");
      
      if (paymentIntentId && sessionId) {
        query = query.or(`stripe_payment_intent_id.eq.${paymentIntentId},stripe_payment_intent_id.eq.${sessionId}`);
      } else if (paymentIntentId) {
        query = query.eq("stripe_payment_intent_id", paymentIntentId);
      } else {
        query = query.eq("stripe_payment_intent_id", sessionId);
      }

      const { data: order } = await query.maybeSingle();
      existingOrder = order;
    }

    if (existingOrder) {
      // If we found it by sessionId or internal ID, but now we have a real paymentIntentId, update it for future webhooks
      if (paymentIntentId && !existingOrder.extra_data?.pi_id) {
         await supabaseAdmin
           .from("clover_orders")
           .update({ stripe_payment_intent_id: paymentIntentId })
           .eq("id", existingOrder.id);
      }
    }

    // 4. HANDLE EVENTS
    switch (event.type) {
      case "checkout.session.completed":
      case "payment_intent.succeeded": {
        // 4a. GET METADATA (with DB fallback)
        let userId = checkoutMetadata?.user_id;
        let cloversAmount = parseInt(checkoutMetadata?.clovers_amount ?? "0", 10);

        // FALLBACK: If metadata is missing but we found the order in DB, use DB values
        if (existingOrder && (!userId || !cloversAmount)) {
           console.log("[stripe-webhook] Metadata missing in Stripe event, using DB fallback");
           userId = userId || (existingOrder as any).user_id;
           cloversAmount = cloversAmount || parseInt((existingOrder as any).extra_data?.clovers_amount ?? "0", 10);
        }

        console.log(`[stripe-webhook] ${event.type}: PI:${paymentIntentId}, user:${userId}, clovers:${cloversAmount}`);

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
              pi_id: paymentIntentId,
            },
          })
          .eq("id", existingOrder.id);

        if (orderError) {
          console.error("[stripe-webhook] Error updating order:", orderError);
          return new Response("DB Error", { status: 500 });
        }

        console.log(`[stripe-webhook] ✅ Success: Order marked as success. Trigger will handle clover increment for user ${userId}`);
        break;
      }

      case "payment_intent.payment_failed": {
        const failureMessage = (event.data.object as any).last_payment_error?.message ?? "Unknown error";

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
          .eq("id", existingOrder.id);

        if (error) {
          console.error("[stripe-webhook] Error marking order as failed:", error);
        }

        console.log(`[stripe-webhook] Order marked as failed for PaymentIntent: ${paymentIntentId}`);
        break;
      }

      case "payment_intent.canceled": {
        console.log(`[stripe-webhook] PaymentIntent canceled: ${paymentIntentId}`);

        await supabaseAdmin
          .from("clover_orders")
          .update({ status: "cancelled" }) 
          .eq("id", existingOrder.id);
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

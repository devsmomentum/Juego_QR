import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@14.25.0?target=deno"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, pago_pago_api',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }
    try {
        // Admin client for DB operations (bypasses RLS)
        const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
        if (!serviceRoleKey) {
            throw new Error("Server Misconfiguration: Missing DB Permissions")
        }

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            serviceRoleKey,
        )

        // Authenticate user via their token
        const authToken = req.headers.get('Authorization')
        if (!authToken) throw new Error("Missing Authorization header")

        const {
            data: { user },
            error: userError,
        } = await supabaseAdmin.auth.getUser(authToken.replace('Bearer ', ''))

        if (userError || !user) {
            throw new Error("Unauthorized")
        }

        const { order_id } = await req.json()
        console.log(`[api_cancel_order] Request to cancel order: ${order_id} by user: ${user.id}`)

        if (!order_id) {
            throw new Error("Missing order_id parameter")
        }

        // 1. Get order details — verify ownership via user_id
        const { data: order, error: fetchError } = await supabaseAdmin
            .from('clover_orders')
            .select('pago_pago_order_id, status, user_id, extra_data, gateway, stripe_payment_intent_id')
            .eq('id', order_id)
            .single()

        if (fetchError || !order) {
            console.error(`[api_cancel_order] Order ${order_id} not found:`, fetchError)
            throw new Error("Orden no encontrada")
        }

        // Security: Verify the user owns this order
        if (order.user_id !== user.id) {
            throw new Error("No autorizado para cancelar esta orden")
        }

        if (order.status !== 'pending') {
            throw new Error(`No se puede cancelar una orden con estado: ${order.status}`)
        }

        // 2. Optimistic: Mark as cancelled in DB FIRST so client gets fast response
        const existingExtra = order.extra_data ?? {}
        const { error: updateError } = await supabaseAdmin
            .from('clover_orders')
            .update({
                status: 'cancelled',
                updated_at: new Date().toISOString(),
                extra_data: {
                    ...existingExtra,
                    cancelled_at: new Date().toISOString(),
                }
            })
            .eq('id', order_id)

        if (updateError) {
            console.error("Failed to update order status locally:", updateError)
            throw new Error("Error actualizando estado de la orden")
        }

        console.log(`Order ${order_id} marked as cancelled in DB (optimistic). Gateway: ${order.gateway ?? 'unknown'}`)

        // 3. Fire-and-forget: Cancel on the corresponding provider
        const orderGateway = order.gateway ?? 'pago_movil'

        if (orderGateway === 'stripe') {
            // --- STRIPE CANCELLATION ---
            const stripeRef = order.stripe_payment_intent_id
            if (stripeRef) {
                const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')
                if (stripeSecretKey) {
                    try {
                        const stripe = new Stripe(stripeSecretKey, {
                            apiVersion: "2024-06-20",
                            httpClient: Stripe.createFetchHttpClient(),
                        })

                        let cancelStatus = ''
                        if (stripeRef.startsWith('cs_')) {
                            // Checkout Session — expire it instead of cancelling a PI
                            const session = await stripe.checkout.sessions.expire(stripeRef)
                            cancelStatus = session.status ?? 'expired'
                            console.log(`[api_cancel_order] Stripe Checkout Session ${stripeRef} expired. Status: ${cancelStatus}`)
                        } else {
                            // PaymentIntent — cancel directly
                            const pi = await stripe.paymentIntents.cancel(stripeRef)
                            cancelStatus = pi.status
                            console.log(`[api_cancel_order] Stripe PI ${stripeRef} cancelled. Status: ${cancelStatus}`)
                        }
                        
                        await supabaseAdmin
                            .from('clover_orders')
                            .update({
                                extra_data: {
                                    ...existingExtra,
                                    cancelled_at: new Date().toISOString(),
                                    stripe_cancel_status: cancelStatus,
                                }
                            })
                            .eq('id', order_id)
                    } catch (stripeErr: any) {
                        // PaymentIntent may already be cancelled/succeeded — that's OK
                        console.warn(`[api_cancel_order] Stripe cancel for ${stripeRef} failed:`, stripeErr.message)
                        await supabaseAdmin
                            .from('clover_orders')
                            .update({
                                extra_data: {
                                    ...existingExtra,
                                    cancelled_at: new Date().toISOString(),
                                    stripe_cancel_error: stripeErr.message,
                                }
                            })
                            .eq('id', order_id)
                    }
                } else {
                    console.warn('[api_cancel_order] STRIPE_SECRET_KEY not configured, skipping Stripe cancel')
                }
            } else {
                console.warn(`[api_cancel_order] Stripe order ${order_id} has no payment_intent_id`)
            }
        } else {
            // --- PAGO MOVIL CANCELLATION (legacy) ---
            const externalId = order.pago_pago_order_id
            if (externalId) {
                const pagoApiKey = Deno.env.get('PAGO_PAGO_API_KEY')
                if (pagoApiKey) {
                    const cancelUrl = `https://mqlboutjgscjgogqbsjc.supabase.co/functions/v1/api_cancel_order`
                    console.log(`Cancelling order ${order_id} (External: ${externalId}) via Pago a Pago (fire-and-forget)`)

                    fetch(cancelUrl, {
                        method: 'PUT',
                        headers: {
                            'Content-Type': 'application/json',
                            'pago_pago_api': pagoApiKey
                        },
                        body: JSON.stringify({ order_id: externalId }),
                        signal: AbortSignal.timeout(10_000),
                    })
                        .then(async (response) => {
                            const data = await response.json()
                            if (!response.ok) {
                                const errMsg = data?.message || data?.error || ''
                                if (!errMsg.toLowerCase().includes('already cancelled')) {
                                    console.warn("[api_cancel_order] Provider cancel failed:", data)
                                }
                            }
                            await supabaseAdmin
                                .from('clover_orders')
                                .update({
                                    extra_data: {
                                        ...existingExtra,
                                        cancelled_at: new Date().toISOString(),
                                        cancellation_response: data,
                                    }
                                })
                                .eq('id', order_id)
                            console.log(`[api_cancel_order] Provider cancel synced for ${order_id}`)
                        })
                        .catch((providerError) => {
                            console.warn(`[api_cancel_order] Provider cancel failed/timed out for ${order_id}:`, providerError)
                            supabaseAdmin
                                .from('clover_orders')
                                .update({
                                    extra_data: {
                                        ...existingExtra,
                                        cancelled_at: new Date().toISOString(),
                                        provider_cancel_error: String(providerError),
                                    }
                                })
                                .eq('id', order_id)
                        })
                } else {
                    console.warn('[api_cancel_order] PAGO_PAGO_API_KEY not configured')
                }
            } else {
                console.log(`[api_cancel_order] Order ${order_id} has no external ID, DB-only cancel.`)
            }
        }

        // Return immediately — DB is already updated
        return new Response(JSON.stringify({ success: true, message: "Orden cancelada exitosamente" }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        console.error("[api_cancel_order] Error:", error)
        return new Response(JSON.stringify({ error: error.message, success: false }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})

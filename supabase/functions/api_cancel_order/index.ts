import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

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
            .select('pago_pago_order_id, status, user_id, extra_data')
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

        const externalId = order.pago_pago_order_id
        if (!externalId) {
             throw new Error("ID de orden externa no encontrado")
        }

        // 2. Get API Key & Config
        const pagoApiKey = Deno.env.get('PAGO_PAGO_API_KEY')
        if (!pagoApiKey) {
            throw new Error("Server Misconfiguration: Missing PAGO_PAGO_API_KEY")
        }

        // 3. Optimistic: Mark as cancelled in DB FIRST so client gets fast response
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

        console.log(`Order ${order_id} marked as cancelled in DB (optimistic).`)

        // 4. Fire-and-forget: Cancel on Provider (best-effort, don't block response)
        const cancelUrl = `https://mqlboutjgscjgogqbsjc.supabase.co/functions/v1/api_cancel_order`
        console.log(`Cancelling order ${order_id} (External: ${externalId}) via Pago a Pago (fire-and-forget)`)

        // Don't await — let provider call run in background while we return 200 immediately
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

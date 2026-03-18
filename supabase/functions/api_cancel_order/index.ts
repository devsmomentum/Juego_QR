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
            .select('pago_pago_order_id, status, user_id')
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

        const supabaseUrl = Deno.env.get('SUPABASE_URL')
        const cancelUrl = `${supabaseUrl}/functions/v1/api_cancel_order`

        console.log(`Cancelling order ${order_id} (External: ${externalId}) via Pago a Pago`)

        // 3. Cancel on Provider (PUT per documentation)
        const response = await fetch(cancelUrl, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'pago_pago_api': pagoApiKey
            },
            body: JSON.stringify({ order_id: externalId })
        })

        const data = await response.json()

        if (!response.ok) {
            console.error("Pago a Pago cancel failed:", data)
            throw new Error(`Error de pasarela: ${data?.message || data?.error || response.status}`)
        }

        // 4. Update Local DB Status to 'cancelled'
        const { error: updateError } = await supabaseAdmin
            .from('clover_orders')
            .update({ 
                status: 'cancelled',
                updated_at: new Date().toISOString(),
                extra_data: { 
                    cancelled_at: new Date().toISOString(),
                    cancellation_response: data 
                }
            })
            .eq('id', order_id)

        if (updateError) {
            console.error("Failed to update order status locally:", updateError)
            // Still return success because the payment gateway cancelled it
        } else {
            console.log(`Order ${order_id} marked as cancelled in DB.`)
        }

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

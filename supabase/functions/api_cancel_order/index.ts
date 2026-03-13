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
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
        const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
        
        const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
        
        // 1. Authenticate User properly using the Bearer token
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            console.error("[api_cancel_order] Missing Authorization header");
            return new Response(JSON.stringify({ error: "Unauthorized", code: "MISSING_AUTH" }), { 
                status: 401, 
                headers: corsHeaders 
            });
        }

        const token = authHeader.replace('Bearer ', '').trim();
        const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);

        if (authError || !user) {
            console.error("[api_cancel_order] Authentication Failure:", authError?.message);
            return new Response(JSON.stringify({ 
                error: "Unauthorized", 
                details: authError?.message || "User not found",
                code: "AUTH_FAILURE_V3" 
            }), { 
                status: 401, 
                headers: corsHeaders 
            });
        }

        const { order_id } = await req.json()
        console.log(`[api_cancel_order] Request to cancel order: ${order_id} by user: ${user.id}`)

        // 1. Get order details and verify ownership
        const { data: order, error: fetchError } = await supabaseAdmin
            .from('clover_orders')
            .select('pago_pago_order_id, status, user_id')
            .eq('id', order_id)
            .single()

        if (fetchError || !order) {
            console.error(`[api_cancel_order] Order ${order_id} not found:`, fetchError)
            throw new Error("Orden no encontrada")
        }

        if (order.user_id !== user.id) {
            console.error(`[api_cancel_order] User ${user.id} attempted to cancel order ${order_id} owned by ${order.user_id}`)
            throw new Error("No tienes permiso para cancelar esta orden")
        }

        const currentStatus = (order.status || '').toLowerCase();
        if (currentStatus !== 'pending') {
             console.log(`[api_cancel_order] Order ${order_id} has status ${order.status}, cannot cancel.`)
             throw new Error(`No se puede cancelar una orden con estado: ${order.status}`)
        }

        const externalId = order.pago_pago_order_id
        
        // 3. Cancel on Provider if exists, or just proceed if it's Stripe
        let providerResponseOk = true;
        let cancellationData = { note: "Local cancellation" };

        if (externalId) {
            console.log(`Cancelling order ${order_id} (External: ${externalId}) via Pago a Pago`)
            const pagoApiKey = Deno.env.get('PAGO_PAGO_API_KEY')!
            const PAGO_PAGO_URL = Deno.env.get('PAGO_PAGO_CANCEL_URL') || "https://pagoapago.com/api/v1/cancel"

            const response = await fetch(PAGO_PAGO_URL, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'pago_pago_api': pagoApiKey
                },
                body: JSON.stringify({ order_id: externalId })
            })
            
            providerResponseOk = response.ok;
            cancellationData = await response.json();
        } else {
            console.log(`Cancelling Stripe/Local order ${order_id} directly in DB.`)
        }

        // 4. Update Local DB Status to 'cancelled'
        if (providerResponseOk) {
            const { error: updateError } = await supabaseAdmin
                .from('clover_orders')
                .update({ 
                    status: 'cancelled',
                    updated_at: new Date().toISOString(),
                    extra_data: { 
                        cancelled_at: new Date().toISOString(),
                        cancellation_response: cancellationData 
                    }
                })
                .eq('id', order_id)

            if (updateError) {
                console.error("Failed to update order status locally:", updateError)
                // We still return success because the payment gateway cancelled it.
            } else {
                console.log(`Order ${order_id} marked as cancelled in DB.`)
            }
        }

        return new Response(JSON.stringify(cancellationData), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})

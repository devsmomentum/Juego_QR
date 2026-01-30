import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const body = await req.json()
        console.log("Webhook received:", JSON.stringify(body))

        // Validar estructura básica del webhook de Pago a Pago
        // Asumimos que el body trae: { success: true, data: { order_id: "...", status: "...", extra_data: { user_id: "..." } } }
        // OJO: Ajustar según la estructura REAL de la respuesta de Pago a Pago.
        // Basado en lo investigado:
        // Podría ser algo como: { order_id: "...", status: "PAID", ... }

        // Extracción segura de datos
        const orderId = body.id || body.order_id || body.data?.order_id
        const status = body.status || body.data?.status
        const extraData = body.extra_data || body.data?.extra_data || {}
        const userId = extraData.user_id

        if (!orderId || !status) {
            throw new Error("Invalid payload: Missing order_id or status")
        }

        console.log(`Processing Order: ${orderId}, Status: ${status}, User: ${userId}`)

        // Verificar si ya existe la transacción
        const { data: existingTx } = await supabaseClient
            .from('payment_transactions')
            .select('*')
            .eq('order_id', orderId)
            .single()

        // Si no existe, crearla (o actualizar si ya existe)
        if (!existingTx) {
            if (userId) {
                await supabaseClient.from('payment_transactions').insert({
                    order_id: orderId,
                    user_id: userId,
                    status: status,
                    amount: body.amount || body.data?.amount || 0,
                    currency: body.currency || body.data?.currency || 'VES',
                    provider_data: body
                })
            } else {
                console.error("No userId found in webhook extra_data")
            }
        } else {
            await supabaseClient.from('payment_transactions').update({
                status: status,
                updated_at: new Date().toISOString(),
                provider_data: body // Guardar último payload
            }).eq('order_id', orderId)
        }

        // Si el estado es COMPLETADO/PAGADO, dar los tréboles
        // Asumimos status == 'PAID' o 'COMPLETED' (Ajustar según documentación real)
        if (status.toUpperCase() === 'PAID' || status.toUpperCase() === 'COMPLETED') {
            if (userId) {
                // Obtener el monto para calcular tréboles (1:1 según regla)
                const amount = body.amount || body.data?.amount || 0
                const cloversToAdd = Math.floor(Number(amount)) // Redondear hacia abajo

                if (cloversToAdd > 0) {
                    // Usar RPC o player_stats si existe, o actualizar profiles directamente
                    // Como clovers está en profiles:
                    const { data: profile } = await supabaseClient
                        .from('profiles')
                        .select('clovers')
                        .eq('id', userId)
                        .single()

                    const currentClovers = profile?.clovers || 0

                    await supabaseClient.from('profiles').update({
                        clovers: currentClovers + cloversToAdd
                    }).eq('id', userId)

                    console.log(`Added ${cloversToAdd} clovers to user ${userId}`)
                }
            }
        }

        return new Response(JSON.stringify({ success: true }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        console.error("Webhook error:", error)
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})

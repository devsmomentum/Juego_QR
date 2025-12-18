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
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if user is admin (simplified check for now)
    // In production, check a 'role' column in profiles or use RLS
    // const { data: profile } = await supabaseClient.from('profiles').select('role').eq('id', user.id).single()
    // if (profile.role !== 'admin') throw new Error('Forbidden')

    const url = new URL(req.url)
    const path = url.pathname.split('/').pop()

    // --- APPROVE REQUEST ---
    if (path === 'approve-request') {
      const { requestId } = await req.json()
      
      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      const { data: request, error: reqError } = await supabaseAdmin
        .from('game_requests')
        .select('*')
        .eq('id', requestId)
        .single()

      if (reqError) throw reqError

      await supabaseAdmin
        .from('game_requests')
        .update({ status: 'approved' })
        .eq('id', requestId)

      await supabaseAdmin
        .from('event_participants')
        .insert({
          user_id: request.user_id,
          event_id: request.event_id
        })

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- GENERATE CLUES ---
    if (path === 'generate-clues') {
      const { eventId, quantity } = await req.json()
      
      if (!eventId || !quantity) throw new Error('eventId and quantity are required')

      const { error } = await supabaseClient.rpc('generate_clues_for_event', { 
        target_event_id: eventId,
        quantity: quantity
      })

      if (error) throw error

      return new Response(
        JSON.stringify({ success: true, message: 'Clues generated' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- CREATE CLUES BATCH ---
    if (path === 'create-clues-batch') {
      const { eventId, clues } = await req.json()
      
      if (!eventId || !clues || !Array.isArray(clues)) throw new Error('eventId and clues array are required')

      const cluesToInsert = clues.map((clue: any, index: number) => ({
        event_id: eventId,
        sequence_index: index,
        title: clue.title,
        description: clue.description,
        riddle_question: clue.riddle_question,
        riddle_answer: clue.riddle_answer,
        xp_reward: clue.xp_reward || 50,
        coin_reward: clue.coin_reward || 10,
        type: 'qrScan'
      }))

      const { error } = await supabaseClient
        .from('clues')
        .insert(cluesToInsert)

      if (error) throw error

      return new Response(
        JSON.stringify({ success: true, message: 'Clues created' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ error: 'Not Found' }),
      { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

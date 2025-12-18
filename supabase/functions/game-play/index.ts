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

    const url = new URL(req.url)
    const path = url.pathname.split('/').pop()

    // --- GET CLUES (WITH PROGRESS) ---
if (path === 'get-clues') {
  const { eventId } = await req.json()

  // 1. Traer todas las pistas del evento
  const { data: clues, error: cluesError } = await supabaseClient
    .from('clues')
    .select('*')
    .eq('event_id', eventId)
    .order('sequence_index', { ascending: true })

  if (cluesError) throw cluesError
  if (!clues) return new Response(JSON.stringify([]), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  // 2. Traer el progreso real del usuario para este evento
  const { data: progressData } = await supabaseClient
    .from('user_clue_progress')
    .select('clue_id, is_completed, is_locked')
    .eq('user_id', user.id)

  const processedClues = clues.map(clue => {
    const progress = progressData?.find(p => p.clue_id === clue.id)
    
    return {
      ...clue,
      // Si no hay fila en progressData, la pista está bloqueada por defecto
      is_completed: progress?.is_completed ?? false,
      is_locked: progress ? progress.is_locked : (clue.sequence_index === 0 ? false : true)
    }
  })

  return new Response(JSON.stringify(processedClues), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
}

    // --- GET LEADERBOARD ---
    if (path === 'get-leaderboard') {
      const { eventId } = await req.json()
      
      if (!eventId) {
        return new Response(
          JSON.stringify({ error: 'Event ID is required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const { data: leaderboard, error } = await supabaseClient
        .rpc('get_event_leaderboard', { target_event_id: eventId })

      if (error) {
        console.error('Error fetching leaderboard:', error)
        throw error
      }

      // Map to match Flutter Player model
      const mappedLeaderboard = leaderboard.map((entry: any) => ({
        id: entry.user_id,
        name: entry.name,
        avatarUrl: entry.avatar_url,
        level: entry.level,
        totalXP: entry.total_xp, 
        score: entry.score 
      }))

      return new Response(
        JSON.stringify(mappedLeaderboard),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- START GAME ---
    if (path === 'start-game') {
      const { eventId } = await req.json()
      if (!eventId) throw new Error('eventId is required')

      const { error } = await supabaseClient.rpc('initialize_game_for_user', { 
        target_user_id: user.id,
        target_event_id: eventId
      })
      if (error) throw error

      return new Response(
        JSON.stringify({ message: 'Game started' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- COMPLETE CLUE ---
if (path === 'complete-clue') {
  const { clueId, answer } = await req.json();

  // 1. Usar ADMIN para poder leer la pista aunque el usuario no tenga permiso aún
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  const { data: clue, error: clueError } = await supabaseAdmin
    .from('clues')
    .select('*')
    .eq('id', clueId)
    .single();

  if (clueError || !clue) throw new Error('Clue not found')

  if (clue.riddle_answer && answer && clue.riddle_answer.toLowerCase() !== answer.toLowerCase()) {
     return new Response(JSON.stringify({ error: 'Incorrect answer' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }

  // 2. Marcar pista actual como completada
  await supabaseAdmin
    .from('user_clue_progress')
    .update({ is_completed: true, is_locked: false, completed_at: new Date().toISOString() })
    .eq('user_id', user.id)
    .eq('clue_id', clueId)

  // 3. DESBLOQUEAR SIGUIENTE PISTA (Usamos supabaseAdmin aquí es CLAVE)
  const { data: nextClue } = await supabaseAdmin
    .from('clues')
    .select('id, sequence_index')
    .eq('event_id', clue.event_id)
    .gt('sequence_index', clue.sequence_index)
    .order('sequence_index', { ascending: true })
    .limit(1)
    .maybeSingle()

  if (nextClue) {
    // Intentamos actualizar si ya existe la fila, si no, la insertamos
    const { data: existingProgress } = await supabaseAdmin
      .from('user_clue_progress')
      .select('id')
      .eq('user_id', user.id)
      .eq('clue_id', nextClue.id)
      .maybeSingle()

    if (existingProgress) {
      await supabaseAdmin
        .from('user_clue_progress')
        .update({ is_locked: false })
        .eq('id', existingProgress.id)
    } else {
      await supabaseAdmin
        .from('user_clue_progress')
        .insert({ 
          user_id: user.id, 
          clue_id: nextClue.id, 
          is_locked: false, 
          is_completed: false 
        })
    }
  }

  // 4. Premios (Corregido: total_coins)
  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

      if (profile) {
        // Calculamos XP total sumando la recompensa
        const currentTotalXp = Number(profile.total_xp) || Number(profile.experience) || 0
        const rewardXp = Number(clue.xp_reward) || 0
        const newTotalXp = currentTotalXp + rewardXp
        const newCoins = (Number(profile.coins) || 0) + (Number(clue.coin_reward) || 0)

        // Calculamos nivel y residuo (newPartialXp)
        let calculatedLevel = 1
        let tempXp = newTotalXp
        
        while (true) {
          const xpNeededForNext = calculatedLevel * 100
          if (tempXp >= xpNeededForNext) {
            tempXp -= xpNeededForNext
            calculatedLevel++
          } else {
            break
          }
        }
        
        const newPartialXp = tempXp // El residuo que llena la barra de 0 a 100

        // Profesión dinámica
        let newProfession = profile.profession || 'Novice'
        const standardRanks = ['Novice', 'Apprentice', 'Explorer', 'Master', 'Legend']
        if (standardRanks.includes(newProfession)) {
            if (calculatedLevel < 5) newProfession = 'Novice'
            else if (calculatedLevel < 10) newProfession = 'Apprentice'
            else if (calculatedLevel < 20) newProfession = 'Explorer'
            else if (calculatedLevel < 50) newProfession = 'Master'
            else newProfession = 'Legend'
        }

        console.log(`[complete-clue] New Total XP: ${newTotalXp}, Partial: ${newPartialXp}, Level: ${calculatedLevel}`)

        // Actualizamos la DB con ambos campos
        const { error: rewardError } = await supabaseAdmin
          .from('profiles')
          .update({ 
            experience: newPartialXp, // Barra de progreso
            total_xp: newTotalXp,    // Estadísticas
            level: calculatedLevel,
            coins: newCoins,
            profession: newProfession
          })
          .eq('id', user.id)

        if (rewardError) console.error('[complete-clue] Reward Error:', rewardError)
      }

      return new Response(
        JSON.stringify({ success: true, message: 'Clue completed' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    // --- SKIP CLUE ---
    if (path === 'skip-clue') {
      const { clueId } = await req.json()
      
      const { data: clue, error: clueError } = await supabaseClient
        .from('clues')
        .select('*')
        .eq('id', clueId)
        .single()

      if (clueError) throw clueError

      const { error: updateError } = await supabaseClient
        .from('user_clue_progress')
        .update({ is_completed: true, completed_at: new Date().toISOString() })
        .eq('user_id', user.id)
        .eq('clue_id', clueId)

      if (updateError) throw updateError

      const { data: nextClue } = await supabaseClient
        .from('clues')
        .select('id')
        .eq('event_id', clue.event_id)
        .gt('sequence_index', clue.sequence_index)
        .order('sequence_index', { ascending: true })
        .limit(1)
        .maybeSingle()

      if (nextClue) {
        await supabaseClient
          .from('user_clue_progress')
          .update({ is_locked: false })
          .eq('user_id', user.id)
          .eq('clue_id', nextClue.id)
      }

      return new Response(
        JSON.stringify({ success: true, message: 'Clue skipped' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- SABOTAGE RIVAL ---
    if (path === 'sabotage-rival') {
      const { rivalId } = await req.json()
      
      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      const { data: userProfile } = await supabaseAdmin
        .from('profiles')
        .select('coins')
        .eq('id', user.id)
        .single()

      if (!userProfile || userProfile.coins < 50) {
        return new Response(
          JSON.stringify({ error: 'Not enough coins' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      await supabaseAdmin
        .from('profiles')
        .update({ coins: userProfile.coins - 50 })
        .eq('id', user.id)

      const freezeUntil = new Date(Date.now() + 5 * 60 * 1000).toISOString()
      await supabaseAdmin
        .from('profiles')
        .update({ 
          status: 'frozen',
          frozen_until: freezeUntil
        })
        .eq('id', rivalId)

      return new Response(
        JSON.stringify({ success: true, message: 'Rival sabotaged' }),
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

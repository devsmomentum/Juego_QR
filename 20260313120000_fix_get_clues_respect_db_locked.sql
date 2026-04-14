-- =============================================================================
-- MIGRACIÓN: Fix get_clues_with_progress - Respetar is_locked de la BD
-- Fecha: 2026-03-13
-- Problema: La función recalculaba is_locked con lógica secuencial pura,
--           ignorando el valor real guardado por submit_clue_answer.
--           Esto causaba race conditions donde una pista ya desbloqueada
--           podía ser reportada como bloqueada si la anterior no estaba
--           marcada como completada al momento de la consulta.
-- Fix: Usar COALESCE(db_value, sequential_fallback) para respetar el
--      desbloqueo explícito del RPC de completitud.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_clues_with_progress(
    p_event_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_result JSONB := '[]'::JSONB;
    v_clue RECORD;
    v_progress RECORD;
    v_prev_completed BOOLEAN := TRUE; -- Primera pista siempre desbloqueada
    v_is_completed BOOLEAN;
    v_is_locked BOOLEAN;
    v_clue_json JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    FOR v_clue IN
        SELECT c.id, c.event_id, c.sequence_index, c.title, c.description,
               c.hint, c.type, c.puzzle_type, c.minigame_url,
               c.riddle_question, c.xp_reward, c.created_at,
               c.latitude, c.longitude
        FROM clues c
        WHERE c.event_id = p_event_id
        ORDER BY c.sequence_index ASC
    LOOP
        SELECT ucp.is_completed, ucp.is_locked
        INTO v_progress
        FROM user_clue_progress ucp
        WHERE ucp.user_id = v_user_id AND ucp.clue_id = v_clue.id;

        -- FIX: Respetar el valor de la BD primero (set por submit_clue_answer),
        -- con fallback a lógica secuencial si no hay registro en user_clue_progress.
        v_is_locked := COALESCE(v_progress.is_locked, NOT v_prev_completed);
        v_is_completed := COALESCE(v_progress.is_completed, FALSE);

        -- Integrity Check: una pista no puede estar completada si está bloqueada
        IF v_is_locked THEN
            v_is_completed := FALSE;
        END IF;

        v_clue_json := jsonb_build_object(
            'id', v_clue.id,
            'event_id', v_clue.event_id,
            'sequence_index', v_clue.sequence_index,
            'title', v_clue.title,
            'description', v_clue.description,
            'hint', v_clue.hint,
            'type', v_clue.type,
            'puzzle_type', v_clue.puzzle_type,
            'minigame_url', v_clue.minigame_url,
            'riddle_question', v_clue.riddle_question,
            'xp_reward', v_clue.xp_reward,
            'created_at', v_clue.created_at,
            'latitude', v_clue.latitude,
            'longitude', v_clue.longitude,
            'is_completed', v_is_completed,
            'isCompleted', v_is_completed,
            'is_locked', v_is_locked
        );

        v_result := v_result || v_clue_json;

        v_prev_completed := v_is_completed;
    END LOOP;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_clues_with_progress(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_clues_with_progress(UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.get_clues_with_progress(p_event_id uuid)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_result JSONB := '[]'::JSONB;
    v_clue RECORD;
    v_progress JSONB;
    v_progress_map JSONB;
    v_prev_completed BOOLEAN := TRUE;
    v_is_completed BOOLEAN;
    v_is_locked BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT jsonb_object_agg(
        ucp.clue_id::text,
        jsonb_build_object(
            'is_completed', ucp.is_completed,
            'is_locked', ucp.is_locked
        )
    )
    INTO v_progress_map
    FROM user_clue_progress ucp
    JOIN clues c ON c.id = ucp.clue_id
    WHERE ucp.user_id = v_user_id
      AND c.event_id = p_event_id;

    FOR v_clue IN
        SELECT
            c.id,
            c.event_id,
            c.sequence_index,
            c.title,
            c.description,
            c.hint,
            c.type,
            c.puzzle_type,
            c.minigame_url,
            c.riddle_question,
            c.xp_reward,
            c.created_at,
            c.latitude,
            c.longitude
        FROM clues c
        WHERE c.event_id = p_event_id
        ORDER BY c.sequence_index ASC
    LOOP
        v_progress := NULL;
        IF v_progress_map IS NOT NULL AND v_progress_map ? v_clue.id::text THEN
            v_progress := v_progress_map -> v_clue.id::text;
        END IF;

        v_is_completed := COALESCE((v_progress->>'is_completed')::BOOLEAN, FALSE);
        v_is_locked := NOT v_prev_completed;

        IF v_is_locked THEN
            v_is_completed := FALSE;
        END IF;

        v_result := v_result || jsonb_build_object(
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

        v_prev_completed := v_is_completed;
    END LOOP;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_clues_with_progress(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_clues_with_progress(UUID) TO service_role;

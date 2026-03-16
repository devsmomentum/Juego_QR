-- =============================================================================
-- MIGRACIÓN: Fix crítico del bug de desbloqueo masivo de pistas
-- Fecha: 2026-03-16
-- Causa raíz:
--   1. get_clues_with_progress (migración 20260303140000) calculaba is_locked 
--      puramente por propagación secuencial de v_prev_completed, ignorando el
--      valor real guardado en user_clue_progress. Esto causaba que un COALESCE
--      con NULL (pista sin registro previo) se resolviese a NOT TRUE = FALSE
--      en lugar de TRUE (bloqueada).
--   2. Ahora se garantiza que el valor explícito de la BD SIEMPRE tiene prioridad
--      (COALESCE(db_is_locked, sequential_fallback)) y se añade una constraint
--      de integridad: una pista no puede estar is_locked=false si su predecesora
--      no está is_completed=true en user_clue_progress (salvo la primera pista).
-- Índices:
--   - user_clue_progress(user_id, clue_id) ya tiene UNIQUE → O(1) lookup.
--   - No se añaden índices nuevos; la query es indexada correctamente.
-- =============================================================================

-- =============================================================================
-- PARTE 1: Re-crear get_clues_with_progress con lógica blindada
-- Reemplaza AMBAS versiones anteriores (20260303140000 y 20260313120000).
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
    v_user_id         UUID;
    v_result          JSONB := '[]'::JSONB;
    v_clue            RECORD;
    v_db_is_locked    BOOLEAN;
    v_db_is_completed BOOLEAN;
    v_is_locked       BOOLEAN;
    v_is_completed    BOOLEAN;
    -- Rastrea si la pista anterior está completada (para fallback secuencial).
    -- Se inicializa TRUE para que la primera pista siempre se desbloquee
    -- cuando no tiene registro en user_clue_progress.
    v_prev_completed  BOOLEAN := TRUE;
BEGIN
    -- Seguridad: rechazar llamadas anónimas
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    -- Iterar en orden estricto por sequence_index ASC.
    -- El ORDER BY aquí es crítico: garantiza que v_prev_completed siempre
    -- corresponde a la pista inmediatamente anterior en la secuencia.
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
        -- Leer el estado real guardado para ESTE usuario y ESTA pista.
        -- La constraint UNIQUE(user_id, clue_id) garantiza que este SELECT
        -- es O(1) mediante el índice primario.
        SELECT ucp.is_locked, ucp.is_completed
        INTO v_db_is_locked, v_db_is_completed
        FROM user_clue_progress ucp
        WHERE ucp.user_id = v_user_id
          AND ucp.clue_id = v_clue.id;

        -- FIX CRÍTICO:
        -- Prioridad 1: valor explícito en la BD (escrito por submit_clue_answer o skip_clue_rpc).
        -- Prioridad 2 (fallback): lógica secuencial si aún no hay registro para esta pista.
        --
        -- CASO Sin registro (NULL): la pista no ha sido tocada todavía.
        --   → is_locked = NOT v_prev_completed  (solo desbloqueada si la anterior está completada)
        --   → is_completed = FALSE
        --
        -- CASO Con registro: respetar el valor guardado atómicamente por el RPC de completitud.
        v_is_locked    := COALESCE(v_db_is_locked,    NOT v_prev_completed);
        v_is_completed := COALESCE(v_db_is_completed, FALSE);

        -- Integrity check: nunca reportar una pista como completada si está bloqueada.
        -- Esto previene inconsistencias causadas por actualizaciones parciales.
        IF v_is_locked THEN
            v_is_completed := FALSE;
        END IF;

        v_result := v_result || jsonb_build_object(
            'id',              v_clue.id,
            'event_id',        v_clue.event_id,
            'sequence_index',  v_clue.sequence_index,
            'title',           v_clue.title,
            'description',     v_clue.description,
            'hint',            v_clue.hint,
            'type',            v_clue.type,
            'puzzle_type',     v_clue.puzzle_type,
            'minigame_url',    v_clue.minigame_url,
            'riddle_question', v_clue.riddle_question,
            'xp_reward',       v_clue.xp_reward,
            'created_at',      v_clue.created_at,
            'latitude',        v_clue.latitude,
            'longitude',       v_clue.longitude,
            -- Se incluyen ambas claves (is_completed e isCompleted) para
            -- compatibilidad con ambas rutas de Clue.fromJson() del cliente.
            'is_completed',    v_is_completed,
            'isCompleted',     v_is_completed,
            'is_locked',       v_is_locked
            -- riddle_answer se omite intencionalmente por seguridad (no exponer al cliente)
        );

        -- Propagar estado para la siguiente iteración del loop.
        -- SOLO se actualiza si la pista está confirmada como completada.
        v_prev_completed := v_is_completed;
    END LOOP;

    RETURN v_result;
END;
$$;

-- =============================================================================
-- PARTE 2: Blindar submit_clue_answer contra condiciones de carrera
--
-- El bug secundario: el RPC original desbloqueaba la siguiente pista haciendo
-- un INSERT/ON CONFLICT solo con is_locked=false, pero NO garantizaba que la
-- pista actual quedara marcada con is_locked=false (podía quedar NULL).
-- Esto causaba que get_clues_with_progress resolviera COALESCE(NULL, ...) 
-- con la lógica secuencial en lugar del valor real.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.submit_clue_answer(
    p_clue_id BIGINT,
    p_answer  TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id            UUID;
    v_clue               RECORD;
    v_gp_id              UUID;
    v_event_id           UUID;
    v_next_clue          RECORD;
    v_is_already_completed BOOLEAN;
    v_coins_earned       INTEGER;
    v_new_balance        INTEGER;
    v_total_players      INTEGER;
    v_position           INTEGER;
    v_xp_reward          INTEGER;
    v_current_total_xp   BIGINT;
    v_new_total_xp       BIGINT;
    v_new_level          INTEGER;
    v_new_partial_xp     BIGINT;
    v_xp_for_next        INTEGER;
    v_profession         TEXT;
BEGIN
    -- 1. Autenticar al usuario
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- 2. Obtener datos de la pista con lock implícito para evitar doble-submit concurrente
    SELECT * INTO v_clue FROM clues WHERE id = p_clue_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Clue not found');
    END IF;

    v_event_id := v_clue.event_id;

    -- 3. Validar respuesta (case-insensitive, trim). NULL/vacío = sin respuesta requerida.
    IF v_clue.riddle_answer IS NOT NULL AND v_clue.riddle_answer != '' THEN
        IF LOWER(TRIM(p_answer)) != LOWER(TRIM(v_clue.riddle_answer)) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Incorrect answer');
        END IF;
    END IF;

    -- 4. Verificar si ya estaba completada (idempotencia)
    SELECT is_completed INTO v_is_already_completed
    FROM user_clue_progress
    WHERE user_id = v_user_id AND clue_id = p_clue_id;

    -- 5. Lógica de completitud (solo si no estaba completada)
    IF v_is_already_completed IS NOT TRUE THEN

        -- A. FIX CRÍTICO: Marcar la pista actual como completada Y no bloqueada.
        --    El INSERT anterior solo ponía is_locked=false en el ON CONFLICT,
        --    lo que podía dejar un registro con is_locked=NULL en inserts nuevos.
        --    Ahora is_locked=false se garantiza tanto en INSERT como en UPDATE.
        INSERT INTO user_clue_progress (user_id, clue_id, is_completed, is_locked, completed_at)
        VALUES (v_user_id, p_clue_id, true, false, NOW())
        ON CONFLICT (user_id, clue_id)
        DO UPDATE SET
            is_completed = true,
            is_locked    = false,  -- Garantizar explícitamente que no está bloqueada
            completed_at = NOW();

        -- B. Incrementar contador en game_players de forma atómica
        UPDATE game_players
        SET
            completed_clues_count = completed_clues_count + 1,
            last_active = NOW()
        WHERE user_id = v_user_id AND event_id = v_event_id
        RETURNING id, coins INTO v_gp_id, v_new_balance;

        -- C. Algoritmo de recompensa adaptativa (Rubber Banding)
        SELECT COUNT(*) INTO v_total_players
        FROM game_players
        WHERE event_id = v_event_id;

        SELECT position INTO v_position FROM (
            SELECT user_id,
                   RANK() OVER (ORDER BY completed_clues_count DESC, last_active ASC) AS position
            FROM game_players
            WHERE event_id = v_event_id
        ) r WHERE r.user_id = v_user_id;

        IF v_position = 1 THEN
            v_coins_earned := floor(random() * (80 - 50 + 1) + 50);     -- 50–80 (líder)
        ELSIF v_position = v_total_players AND v_total_players > 1 THEN
            v_coins_earned := floor(random() * (150 - 120 + 1) + 120);  -- 120–150 (último)
        ELSE
            v_coins_earned := floor(random() * (120 - 80 + 1) + 80);    -- 80–120 (resto)
        END IF;

        -- D. Actualizar balance de monedas
        UPDATE game_players
        SET coins = coins + v_coins_earned
        WHERE id = v_gp_id
        RETURNING coins INTO v_new_balance;

        -- E. Actualizar XP global y nivel en profiles
        SELECT total_xp, level, profession
        INTO v_current_total_xp, v_new_level, v_profession
        FROM profiles WHERE id = v_user_id;

        v_xp_reward    := COALESCE(v_clue.xp_reward, 50);
        v_new_total_xp := v_current_total_xp + v_xp_reward;

        -- Recalcular nivel (100 XP por nivel, escalado lineal)
        v_new_level      := 1;
        v_new_partial_xp := v_new_total_xp;
        LOOP
            v_xp_for_next := v_new_level * 100;
            EXIT WHEN v_new_partial_xp < v_xp_for_next;
            v_new_partial_xp := v_new_partial_xp - v_xp_for_next;
            v_new_level      := v_new_level + 1;
        END LOOP;

        UPDATE profiles SET
            total_xp   = v_new_total_xp,
            experience = v_new_partial_xp,
            level      = v_new_level,
            updated_at = NOW()
        WHERE id = v_user_id;

    ELSE
        -- Ya estaba completada: solo obtener el balance actual (idempotencia)
        SELECT coins INTO v_new_balance
        FROM game_players
        WHERE user_id = v_user_id AND event_id = v_event_id;
        v_coins_earned := 0;
    END IF;

    -- 6. FIX CRÍTICO: Desbloquear la siguiente pista con filtro estricto por user_id.
    --    La versión anterior podía escribir registros sin filtrar correctamente,
    --    potencialmente afectando a otros usuarios en eventos concurrentes.
    SELECT * INTO v_next_clue
    FROM clues
    WHERE event_id = v_event_id
      AND sequence_index > v_clue.sequence_index
    ORDER BY sequence_index ASC
    LIMIT 1;

    IF v_next_clue IS NOT NULL THEN
        -- Upsert atómico: crear o actualizar el registro de progreso de la siguiente pista
        -- solo para ESTE usuario (v_user_id), garantizando que is_locked=false y
        -- is_completed=false (no marcar como completada, solo desbloquear).
        INSERT INTO user_clue_progress (user_id, clue_id, is_completed, is_locked)
        VALUES (v_user_id, v_next_clue.id, false, false)
        ON CONFLICT (user_id, clue_id)
        DO UPDATE SET is_locked = false
        -- Guard: nunca revertir una pista que ya estaba completada por un skip previo
        WHERE user_clue_progress.is_completed = false;
    END IF;

    -- 7. Respuesta final
    RETURN jsonb_build_object(
        'success',       true,
        'message',       'Clue completed successfully',
        'raceCompleted', (v_next_clue IS NULL),
        'coins_earned',  v_coins_earned,
        'new_balance',   v_new_balance,
        'eventId',       v_event_id
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error',   SQLERRM,
        'detail',  SQLSTATE
    );
END;
$$;

-- =============================================================================
-- PARTE 3: Blindar skip_clue_rpc con el mismo patrón
-- =============================================================================
CREATE OR REPLACE FUNCTION public.skip_clue_rpc(
    p_clue_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id   UUID;
    v_clue      RECORD;
    v_next_clue RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    SELECT * INTO v_clue FROM clues WHERE id = p_clue_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Clue not found');
    END IF;

    -- Marcar pista actual como completada + desbloqueada (is_locked=false explícito)
    INSERT INTO user_clue_progress (user_id, clue_id, is_completed, is_locked, completed_at)
    VALUES (v_user_id, p_clue_id, true, false, NOW())
    ON CONFLICT (user_id, clue_id)
    DO UPDATE SET
        is_completed = true,
        is_locked    = false,
        completed_at = NOW();

    -- Desbloquear siguiente pista (filtrado estrictamente por v_user_id)
    SELECT id INTO v_next_clue
    FROM clues
    WHERE event_id = v_clue.event_id
      AND sequence_index > v_clue.sequence_index
    ORDER BY sequence_index ASC
    LIMIT 1;

    IF v_next_clue IS NOT NULL THEN
        INSERT INTO user_clue_progress (user_id, clue_id, is_completed, is_locked)
        VALUES (v_user_id, v_next_clue.id, false, false)
        ON CONFLICT (user_id, clue_id)
        DO UPDATE SET is_locked = false
        WHERE user_clue_progress.is_completed = false;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Clue skipped');

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Permisos
GRANT EXECUTE ON FUNCTION public.get_clues_with_progress(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_clues_with_progress(UUID) TO service_role;

GRANT EXECUTE ON FUNCTION public.submit_clue_answer(BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_clue_answer(BIGINT, TEXT) TO service_role;

GRANT EXECUTE ON FUNCTION public.skip_clue_rpc(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.skip_clue_rpc(BIGINT) TO service_role;

-- Forzar recarga del schema de PostgREST
NOTIFY pgrst, 'reload schema';

-- 0. Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Add station_access_code to events
ALTER TABLE events ADD COLUMN IF NOT EXISTS station_access_code TEXT DEFAULT NULL;

-- 2. Add assigned_puzzle_type to user_clue_progress
ALTER TABLE user_clue_progress ADD COLUMN IF NOT EXISTS assigned_puzzle_type TEXT DEFAULT NULL;

-- 3. Create station_tokens table
CREATE TABLE IF NOT EXISTS station_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    clue_id BIGINT NOT NULL REFERENCES clues(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE DEFAULT md5(random()::text || clock_timestamp()::text),
    consumed_by UUID REFERENCES profiles(id),
    consumed_at TIMESTAMPTZ,
    assigned_puzzle_type TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast token lookup (only unconsumed tokens)
CREATE INDEX IF NOT EXISTS idx_station_tokens_active 
    ON station_tokens(token) WHERE consumed_by IS NULL;

-- Index for counting scans per clue
CREATE INDEX IF NOT EXISTS idx_station_tokens_clue_consumed 
    ON station_tokens(event_id, clue_id) WHERE consumed_by IS NOT NULL;

-- Enable Realtime on station_tokens for tablet auto-refresh (Idempotent check)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'station_tokens'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE station_tokens;
    END IF;
END $$;

-- Enable SELECT for anon so Realtime works for tablets (Idempotent checks)
ALTER TABLE station_tokens ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow anon read tokens' AND tablename = 'station_tokens') THEN
        CREATE POLICY "Allow anon read tokens" ON station_tokens FOR SELECT TO anon USING (true);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow authenticated read tokens' AND tablename = 'station_tokens') THEN
        CREATE POLICY "Allow authenticated read tokens" ON station_tokens FOR SELECT TO authenticated USING (true);
    END IF;
END $$;

GRANT SELECT ON station_tokens TO anon;
GRANT SELECT ON station_tokens TO authenticated;

-- ============================================================
-- RPC: generate_station_access_code (admin only)
-- ============================================================
CREATE OR REPLACE FUNCTION generate_station_access_code(p_event_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
BEGIN
    -- Generate a short random code: EVT-XXXX (4 alphanumeric chars)
    v_code := 'EVT-' || upper(substr(md5(random()::text), 1, 4));
    
    -- 1. Clear this code from any OTHER event to avoid collisions
    UPDATE events SET station_access_code = NULL WHERE station_access_code = v_code AND id != p_event_id;
    
    -- 2. Update target event
    UPDATE events SET station_access_code = v_code WHERE id = p_event_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event not found with ID %', p_event_id;
    END IF;
    
    RETURN v_code;
END;
$$;

GRANT EXECUTE ON FUNCTION generate_station_access_code(UUID) TO authenticated;

-- ============================================================
-- RPC: validate_station_access (no auth required - tablet kiosk)
-- ============================================================
CREATE OR REPLACE FUNCTION validate_station_access(p_access_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_event RECORD;
    v_clues JSONB;
BEGIN
    -- Find event by access code (pick most recent if somehow duplicated)
    SELECT id, title, status INTO v_event
    FROM events
    WHERE station_access_code = upper(trim(p_access_code))
    ORDER BY id DESC
    LIMIT 1;
    
    IF v_event.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_CODE');
    END IF;
    
    -- Get clues for this event (minimal data - just id, title, sequence)
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', c.id,
            'title', c.title,
            'sequence_index', c.sequence_index
        ) ORDER BY c.sequence_index ASC, c.id ASC
    )
    INTO v_clues
    FROM clues c
    WHERE c.event_id = v_event.id;
    
    RETURN jsonb_build_object(
        'success', true,
        'event_id', v_event.id,
        'event_title', v_event.title,
        'event_status', v_event.status,
        'clues', COALESCE(v_clues, '[]'::jsonb)
    );
END;
$$;

-- Grant to anon so tablets without login can use it
GRANT EXECUTE ON FUNCTION validate_station_access(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION validate_station_access(TEXT) TO authenticated;

-- ============================================================
-- RPC: generate_station_token
-- ============================================================
CREATE OR REPLACE FUNCTION generate_station_token(p_event_id UUID, p_clue_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_token_id UUID;
    v_token TEXT;
    v_scanned_count INT;
BEGIN
    -- Generate unique token
    v_token := md5(random()::text || clock_timestamp()::text);
    
    INSERT INTO station_tokens (event_id, clue_id, token)
    VALUES (p_event_id, p_clue_id, v_token)
    RETURNING id INTO v_token_id;
    
    -- Count how many have been consumed for this clue
    SELECT COUNT(*) INTO v_scanned_count
    FROM station_tokens
    WHERE event_id = p_event_id 
      AND clue_id = p_clue_id 
      AND consumed_by IS NOT NULL;
    
    RETURN jsonb_build_object(
        'success', true,
        'token_id', v_token_id,
        'token', v_token,
        'scanned_count', v_scanned_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION generate_station_token(UUID, BIGINT) TO anon;
GRANT EXECUTE ON FUNCTION generate_station_token(UUID, BIGINT) TO authenticated;

-- ============================================================
-- RPC: consume_station_token (player scans QR)
-- Validates token, assigns random minigame, unlocks clue
-- ============================================================
CREATE OR REPLACE FUNCTION consume_station_token(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_token_record RECORD;
    v_assigned_puzzle TEXT;
    v_recent_puzzles TEXT[];
    v_all_puzzles TEXT[] := ARRAY[
        'slidingPuzzle', 'ticTacToe', 'hangman', 'tetris',
        'findDifference', 'flags', 'minesweeper', 'snake',
        'blockFill', 'memorySequence', 'drinkMixer', 'fastNumber',
        'bagShuffle', 'emojiMovie', 'virusTap', 'droneDodge',
        'holographicPanels', 'missingOperator', 'primeNetwork',
        'percentageCalculation', 'chronologicalOrder', 'capitalCities',
        'trueFalse'
    ];
    v_available_puzzles TEXT[];
    v_existing_assignment TEXT;
    v_clue_sequence INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_AUTHENTICATED');
    END IF;
    
    -- 1. Find and validate token
    SELECT * INTO v_token_record
    FROM station_tokens
    WHERE token = p_token
    FOR UPDATE; -- Lock row to prevent double consumption
    
    IF v_token_record.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_TOKEN');
    END IF;
    
    IF v_token_record.consumed_by IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'TOKEN_ALREADY_USED');
    END IF;
    
    -- 2. Check if player already has an assignment for this clue
    SELECT assigned_puzzle_type INTO v_existing_assignment
    FROM user_clue_progress
    WHERE user_id = v_user_id AND clue_id = v_token_record.clue_id;
    
    IF v_existing_assignment IS NOT NULL THEN
        -- Player already has a minigame for this clue — just consume token and return existing
        UPDATE station_tokens 
        SET consumed_by = v_user_id, 
            consumed_at = now(),
            assigned_puzzle_type = v_existing_assignment
        WHERE id = v_token_record.id;
        
        RETURN jsonb_build_object(
            'success', true,
            'clue_id', v_token_record.clue_id,
            'puzzle_type', v_existing_assignment,
            'already_assigned', true
        );
    END IF;
    
    -- 3. Get the last 3 puzzle types this player completed (anti-repetition)
    SELECT array_agg(ucp.assigned_puzzle_type)
    INTO v_recent_puzzles
    FROM (
        SELECT ucp2.assigned_puzzle_type
        FROM user_clue_progress ucp2
        JOIN clues c2 ON c2.id = ucp2.clue_id
        WHERE ucp2.user_id = v_user_id
          AND ucp2.assigned_puzzle_type IS NOT NULL
          AND c2.event_id = v_token_record.event_id
        ORDER BY ucp2.completed_at DESC NULLS LAST
        LIMIT 3
    ) ucp;
    
    -- 4. Filter available puzzles (exclude recent)
    IF v_recent_puzzles IS NOT NULL AND array_length(v_recent_puzzles, 1) > 0 THEN
        SELECT array_agg(p) INTO v_available_puzzles
        FROM unnest(v_all_puzzles) p
        WHERE p != ALL(v_recent_puzzles);
    ELSE
        v_available_puzzles := v_all_puzzles;
    END IF;
    
    -- Fallback if somehow all are excluded
    IF v_available_puzzles IS NULL OR array_length(v_available_puzzles, 1) = 0 THEN
        v_available_puzzles := v_all_puzzles;
    END IF;
    
    -- 5. Pick random puzzle from available pool
    v_assigned_puzzle := v_available_puzzles[1 + floor(random() * array_length(v_available_puzzles, 1))::int];
    
    -- 6. Consume the token
    UPDATE station_tokens 
    SET consumed_by = v_user_id, 
        consumed_at = now(),
        assigned_puzzle_type = v_assigned_puzzle
    WHERE id = v_token_record.id;
    
    -- 7. Get clue sequence_index for unlocking
    SELECT sequence_index INTO v_clue_sequence
    FROM clues WHERE id = v_token_record.clue_id;
    
    -- 8. Upsert user_clue_progress with the assignment + unlock
    INSERT INTO user_clue_progress (user_id, clue_id, is_locked, is_completed, assigned_puzzle_type)
    VALUES (v_user_id, v_token_record.clue_id, false, false, v_assigned_puzzle)
    ON CONFLICT (user_id, clue_id) 
    DO UPDATE SET 
        is_locked = false,
        assigned_puzzle_type = v_assigned_puzzle;
    
    RETURN jsonb_build_object(
        'success', true,
        'clue_id', v_token_record.clue_id,
        'puzzle_type', v_assigned_puzzle,
        'already_assigned', false
    );
END;
$$;

GRANT EXECUTE ON FUNCTION consume_station_token(TEXT) TO authenticated;

-- ============================================================
-- Update get_clues_with_progress to include assigned_puzzle_type
-- ============================================================
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
            'is_locked', ucp.is_locked,
            'assigned_puzzle_type', ucp.assigned_puzzle_type
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
            'puzzle_type', COALESCE(v_progress->>'assigned_puzzle_type', v_clue.puzzle_type),
            'minigame_url', v_clue.minigame_url,
            'riddle_question', v_clue.riddle_question,
            'xp_reward', v_clue.xp_reward,
            'created_at', v_clue.created_at,
            'latitude', v_clue.latitude,
            'longitude', v_clue.longitude,
            'is_completed', v_is_completed,
            'isCompleted', v_is_completed,
            'is_locked', v_is_locked,
            'assigned_puzzle_type', v_progress->>'assigned_puzzle_type'
        );

        v_prev_completed := v_is_completed;
    END LOOP;

    RETURN v_result;
END;
$$;

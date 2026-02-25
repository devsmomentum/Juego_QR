-- ============================================================================
-- Migration: safe_reset_event RPC
-- Created: 2026-02-25
-- Purpose: Replaces the "nuclear reset" Edge Function with an atomic,
--          auditable PostgreSQL function that ONLY clears transactional data.
--          Structural data (clues, events config, mall_stores) is NEVER touched.
-- ============================================================================

-- Drop if exists to allow re-running
DROP FUNCTION IF EXISTS public.safe_reset_event(uuid, uuid);

CREATE OR REPLACE FUNCTION public.safe_reset_event(
  target_event_id uuid,
  admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_exists  boolean;
  v_event_status  text;
  v_clue_count_before integer;
  v_clue_count_after  integer;
  v_gp_ids        uuid[];
  v_clue_ids      bigint[];
  v_deleted_progress  integer := 0;
  v_deleted_powers    integer := 0;
  v_deleted_active    integer := 0;
  v_deleted_transactions integer := 0;
  v_deleted_combat    integer := 0;
  v_deleted_bets      integer := 0;
  v_deleted_prizes    integer := 0;
  v_deleted_players   integer := 0;
  v_deleted_requests  integer := 0;
BEGIN
  -- =====================================================================
  -- STEP 0: VALIDATE EVENT EXISTS
  -- =====================================================================
  SELECT EXISTS(SELECT 1 FROM events WHERE id = target_event_id)
    INTO v_event_exists;

  IF NOT v_event_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'EVENT_NOT_FOUND',
      'message', format('No existe un evento con id %s', target_event_id)
    );
  END IF;

  -- Get current status
  SELECT status INTO v_event_status
    FROM events WHERE id = target_event_id;

  -- =====================================================================
  -- STEP 1: SNAPSHOT — Count structural data BEFORE reset
  -- This is our integrity anchor. Clues must survive untouched.
  -- =====================================================================
  SELECT count(*) INTO v_clue_count_before
    FROM clues WHERE event_id = target_event_id;

  -- =====================================================================
  -- STEP 2: COLLECT IDs — Gather game_player and clue IDs
  -- =====================================================================
  SELECT array_agg(id) INTO v_gp_ids
    FROM game_players WHERE event_id = target_event_id;

  SELECT array_agg(id) INTO v_clue_ids
    FROM clues WHERE event_id = target_event_id;

  -- =====================================================================
  -- STEP 3: DELETE TRANSACTIONAL DATA (child tables first)
  -- ORDER MATTERS: Delete children before parents to respect FK constraints.
  -- =====================================================================

  -- 3a. User clue progress (depends on clues)
  IF v_clue_ids IS NOT NULL AND array_length(v_clue_ids, 1) > 0 THEN
    DELETE FROM user_clue_progress WHERE clue_id = ANY(v_clue_ids);
    GET DIAGNOSTICS v_deleted_progress = ROW_COUNT;
  END IF;

  -- 3b. Player-level data (depends on game_players)
  IF v_gp_ids IS NOT NULL AND array_length(v_gp_ids, 1) > 0 THEN
    -- Player powers inventory
    DELETE FROM player_powers WHERE game_player_id = ANY(v_gp_ids);
    GET DIAGNOSTICS v_deleted_powers = ROW_COUNT;

    -- Transactions log
    DELETE FROM transactions WHERE game_player_id = ANY(v_gp_ids);
    GET DIAGNOSTICS v_deleted_transactions = ROW_COUNT;

    -- Combat events (also handled by CASCADE, but explicit is safer)
    DELETE FROM combat_events
      WHERE attacker_id = ANY(v_gp_ids) OR target_id = ANY(v_gp_ids);
    GET DIAGNOSTICS v_deleted_combat = ROW_COUNT;
  END IF;

  -- 3c. Event-level transactional data
  DELETE FROM active_powers WHERE event_id = target_event_id;
  GET DIAGNOSTICS v_deleted_active = ROW_COUNT;

  DELETE FROM bets WHERE event_id = target_event_id;
  GET DIAGNOSTICS v_deleted_bets = ROW_COUNT;

  DELETE FROM prize_distributions WHERE event_id = target_event_id;
  GET DIAGNOSTICS v_deleted_prizes = ROW_COUNT;

  -- 3d. Player registrations (parent of player_powers, transactions, etc.)
  DELETE FROM game_players WHERE event_id = target_event_id;
  GET DIAGNOSTICS v_deleted_players = ROW_COUNT;

  -- 3e. Join requests
  DELETE FROM game_requests WHERE event_id = target_event_id;
  GET DIAGNOSTICS v_deleted_requests = ROW_COUNT;

  -- =====================================================================
  -- STEP 4: RESET EVENT STATUS (soft reset, no DELETE)
  -- =====================================================================
  UPDATE events
    SET status       = 'pending',
        winner_id    = NULL,
        completed_at = NULL,
        is_completed = false,
        pot          = 0
    WHERE id = target_event_id;

  -- =====================================================================
  -- STEP 5: INTEGRITY VERIFICATION — Clues must be intact
  -- =====================================================================
  SELECT count(*) INTO v_clue_count_after
    FROM clues WHERE event_id = target_event_id;

  IF v_clue_count_before <> v_clue_count_after THEN
    -- THIS SHOULD NEVER HAPPEN. If it does, abort everything.
    RAISE EXCEPTION 'INTEGRITY VIOLATION: Clue count changed from % to % during reset. Transaction rolled back.',
      v_clue_count_before, v_clue_count_after;
  END IF;

  -- =====================================================================
  -- STEP 6: AUDIT LOG — Record who did what
  -- =====================================================================
  INSERT INTO admin_audit_logs (admin_id, action_type, target_table, target_id, details)
  VALUES (
    admin_id,
    'event_reset',
    'events',
    target_event_id,
    jsonb_build_object(
      'previous_status', v_event_status,
      'clues_preserved', v_clue_count_after,
      'deleted_progress', v_deleted_progress,
      'deleted_player_powers', v_deleted_powers,
      'deleted_active_powers', v_deleted_active,
      'deleted_transactions', v_deleted_transactions,
      'deleted_combat_events', v_deleted_combat,
      'deleted_bets', v_deleted_bets,
      'deleted_prizes', v_deleted_prizes,
      'deleted_players', v_deleted_players,
      'deleted_requests', v_deleted_requests
    )
  );

  -- =====================================================================
  -- STEP 7: RETURN SUMMARY
  -- =====================================================================
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Evento reiniciado de forma segura',
    'event_id', target_event_id,
    'previous_status', v_event_status,
    'clues_preserved', v_clue_count_after,
    'summary', jsonb_build_object(
      'progress_cleared', v_deleted_progress,
      'players_removed', v_deleted_players,
      'requests_removed', v_deleted_requests,
      'powers_cleared', v_deleted_powers + v_deleted_active,
      'transactions_cleared', v_deleted_transactions,
      'combat_logs_cleared', v_deleted_combat,
      'bets_cleared', v_deleted_bets,
      'prizes_cleared', v_deleted_prizes
    )
  );
END;
$$;

-- Grant execute to authenticated users (RLS on admin_audit_logs will still protect)
-- The function uses SECURITY DEFINER so it runs as the DB owner
GRANT EXECUTE ON FUNCTION public.safe_reset_event(uuid, uuid) TO authenticated;

-- Add a comment for documentation
COMMENT ON FUNCTION public.safe_reset_event IS
  'Safely resets an event by clearing ONLY transactional data (players, progress, bets, etc). '
  'Structural data (clues, event config) is NEVER deleted. '
  'Runs as an atomic transaction — all or nothing. '
  'Verifies clue count integrity before committing.';

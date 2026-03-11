-- =============================================================================
-- Migration: start_event — bulk-enroll approved game_requests into game_players
-- =============================================================================
-- Problem:
--   When an admin presses "Iniciar Evento" on a manual online event, all 50+
--   waiting players receive the Realtime notification simultaneously.
--   Many still only have an approved row in `game_requests` (not yet in
--   `game_players`). When every client calls startGame() at the same time, all
--   50 try to INSERT into game_players in the same second → race conditions,
--   DB spikes, inconsistent visual states.
--
-- Solution:
--   Replace the existing `start_event` RPC with a version that, as part of the
--   same atomic transaction, promotes every approved game_request to a
--   game_players row BEFORE changing the event status to 'active'.
--   When clients later call startGame() the row already exists → the call
--   becomes an idempotent no-op (upsert / early-return).
--
--   The original start_event behaviour is fully preserved.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.start_event(p_event_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event           RECORD;
  v_enrolled_count  INT := 0;
  v_req             RECORD;
BEGIN
  -- Auth guard
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  -- Fetch event
  SELECT id, status, type, max_participants, configured_winners
  INTO v_event
  FROM public.events
  WHERE id = p_event_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'EVENT_NOT_FOUND');
  END IF;

  -- Idempotent: already active
  IF v_event.status = 'active' THEN
    RETURN jsonb_build_object('success', true, 'already_active', true);
  END IF;

  -- Only pending events can be activated
  IF v_event.status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'NOT_ELIGIBLE',
      'current_status', v_event.status
    );
  END IF;

  -- ────────────────────────────────────────────────────────────────────────────
  -- Bulk-enroll: promote every approved game_request to a game_players row.
  -- Uses INSERT ... ON CONFLICT DO NOTHING so it is safe to run multiple times.
  -- ────────────────────────────────────────────────────────────────────────────
  FOR v_req IN
    SELECT gr.user_id
    FROM   public.game_requests gr
    WHERE  gr.event_id = p_event_id
      AND  gr.status   = 'approved'
      AND  NOT EXISTS (
             SELECT 1
             FROM   public.game_players gp
             WHERE  gp.event_id = p_event_id
               AND  gp.user_id  = gr.user_id
           )
  LOOP
    INSERT INTO public.game_players (
      event_id, user_id, status, coins, lives,
      completed_clues_count, is_protected, last_active
    ) VALUES (
      p_event_id, v_req.user_id, 'active', 0, 3,
      0, false, NOW()
    )
    ON CONFLICT (event_id, user_id) DO NOTHING;

    v_enrolled_count := v_enrolled_count + 1;
  END LOOP;

  -- ────────────────────────────────────────────────────────────────────────────
  -- Activate the event
  -- ────────────────────────────────────────────────────────────────────────────
  UPDATE public.events
  SET status = 'active'
  WHERE id = p_event_id
    AND status = 'pending'; -- race-condition guard

  RETURN jsonb_build_object(
    'success',        true,
    'event_id',       p_event_id,
    'bulk_enrolled',  v_enrolled_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_event(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_event(uuid) TO service_role;

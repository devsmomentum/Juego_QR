-- ============================================================
-- Migration: Online Event Pending Flow
-- Description: Adds auto-activation / auto-cancellation logic
--   for automated online events.
--
--   1. auto_start_online_event RPC:
--      Called client-side when the pending countdown reaches zero.
--      * Countdown NOT expired yet       -> COUNTDOWN_NOT_EXPIRED (no-op, safe guard).
--      * Countdown expired + enough players (>= min_players_to_start)
--                                        -> event status set to 'active'.
--      * Countdown expired + NOT enough players
--                                        -> event status set to 'cancelled'.
--      The RPC is idempotent: returns success if the event is already active.
--
--   2. check_online_event_room_full trigger:
--      Fires AFTER INSERT on game_players.
--      If the room fills up (current >= max_participants) while the event
--      is still pending, the event is immediately activated regardless of
--      how much time is left in the countdown.
-- ============================================================

-- ============================================================
-- 1.  auto_start_online_event
-- ============================================================
CREATE OR REPLACE FUNCTION public.auto_start_online_event(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event               RECORD;
  v_config              JSONB;
  v_min_players         INT;
  v_player_count        INT;
  v_configured_winners  INT;
BEGIN
  -- Auth required
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  -- Fetch event with its scheduled date
  SELECT id, status, type, max_participants, title, date
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

  -- Already cancelled by a previous call
  IF v_event.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'error', 'EVENT_CANCELLED', 'cancelled', true);
  END IF;

  -- Only processable for pending online events
  IF v_event.type != 'online' OR v_event.status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'NOT_ELIGIBLE',
      'current_status', v_event.status, 'type', v_event.type
    );
  END IF;

  -- Guard: countdown must have expired.
  -- The client calls this when the UI timer hits zero, but the server
  -- double-checks so the RPC cannot be abused before time is up.
  IF NOW() AT TIME ZONE 'UTC' < v_event.date THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'COUNTDOWN_NOT_EXPIRED',
      'seconds_remaining',
      EXTRACT(EPOCH FROM (v_event.date - (NOW() AT TIME ZONE 'UTC')))::int
    );
  END IF;

  -- Read min_players_to_start from automation config (default 5)
  SELECT value INTO v_config
  FROM public.app_config
  WHERE key = 'online_automation_config';

  v_min_players := COALESCE((v_config->>'min_players_to_start')::int, 5);

  -- Count non-spectator, non-banned players
  SELECT COUNT(*) INTO v_player_count
  FROM public.game_players
  WHERE event_id = p_event_id
    AND status NOT IN ('spectator', 'banned');

  -- Decision point
  IF v_player_count >= v_min_players THEN

    -- Dynamic winner count: <6 players→1, <11→2, else→3
    v_configured_winners := CASE
      WHEN v_player_count < 6  THEN 1
      WHEN v_player_count < 11 THEN 2
      ELSE 3
    END;

    -- Enough players -> activate
    UPDATE public.events
    SET status = 'active',
        configured_winners = v_configured_winners
    WHERE id = p_event_id
      AND status = 'pending'; -- race-condition guard

    RETURN jsonb_build_object(
      'success', true,
      'event_id', p_event_id,
      'players_count', v_player_count
    );

  ELSE

    -- Not enough players -> delete the event.
    -- Row is deleted so the event and all cascade rows are removed.
    DELETE FROM public.events
    WHERE id = p_event_id
      AND status = 'pending'; -- race-condition guard

    RETURN jsonb_build_object(
      'success', false,
      'error', 'EVENT_CANCELLED',
      'cancelled', true,
      'current', v_player_count,
      'required', v_min_players
    );

  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_start_online_event(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_start_online_event(uuid) TO service_role;

-- ============================================================
-- 2.  Trigger: auto-activate when room fills up.
--     Activates IMMEDIATELY when max_participants is reached,
--     regardless of how much time remains in the countdown.
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_online_event_room_full()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event               RECORD;
  v_player_count        INT;
  v_configured_winners  INT;
BEGIN
  -- Skip spectators and banned players
  IF NEW.status IN ('spectator', 'banned') THEN
    RETURN NEW;
  END IF;

  -- Fetch event
  SELECT id, status, type, max_participants
  INTO v_event
  FROM public.events
  WHERE id = NEW.event_id;

  -- Only act on online events in pending state
  IF NOT FOUND
     OR v_event.type != 'online'
     OR v_event.status != 'pending' THEN
    RETURN NEW;
  END IF;

  -- Count all non-spectator, non-banned players for this event
  SELECT COUNT(*) INTO v_player_count
  FROM public.game_players
  WHERE event_id = NEW.event_id
    AND status NOT IN ('spectator', 'banned');

  -- Room full -> activate immediately (no countdown check here)
  IF v_player_count >= v_event.max_participants THEN
    -- Dynamic winner count: <6 players→1, <11→2, else→3
    v_configured_winners := CASE
      WHEN v_player_count < 6  THEN 1
      WHEN v_player_count < 11 THEN 2
      ELSE 3
    END;

    UPDATE public.events
    SET status = 'active',
        configured_winners = v_configured_winners
    WHERE id = NEW.event_id
      AND status = 'pending'; -- race-condition guard
  END IF;

  RETURN NEW;
END;
$$;

-- Drop and recreate the trigger to ensure idempotency
DROP TRIGGER IF EXISTS trg_check_online_event_room_full ON public.game_players;

CREATE TRIGGER trg_check_online_event_room_full
AFTER INSERT ON public.game_players
FOR EACH ROW
EXECUTE FUNCTION public.check_online_event_room_full();

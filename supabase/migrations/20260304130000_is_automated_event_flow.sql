-- ============================================================
-- Migration: is_automated field + scoped auto-start logic
-- Description:
--   Adds is_automated BOOLEAN to events so auto-created events
--   (via the automate-online-events edge function) can be
--   distinguished from manually-created online events.
--
--   Rules:
--   • is_automated = TRUE  → system auto-starts on countdown end
--                            (or immediately when room fills up).
--   • is_automated = FALSE → admin must manually start the event
--                            via the admin panel (existing flow).
-- ============================================================

-- 1. Add column
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS is_automated BOOLEAN NOT NULL DEFAULT FALSE;

-- ============================================================
-- 2.  auto_start_online_event — only fires for automated events
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

  -- Fetch event
  SELECT id, status, type, max_participants, date, is_automated
  INTO v_event
  FROM public.events
  WHERE id = p_event_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'EVENT_NOT_FOUND');
  END IF;

  -- Only automated online events
  IF NOT v_event.is_automated OR v_event.type != 'online' THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_AUTOMATED');
  END IF;

  -- Idempotent: already active
  IF v_event.status = 'active' THEN
    RETURN jsonb_build_object('success', true, 'already_active', true);
  END IF;

  -- Already cancelled
  IF v_event.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'error', 'EVENT_CANCELLED', 'cancelled', true);
  END IF;

  -- Only pending events can be transitioned
  IF v_event.status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'NOT_ELIGIBLE',
      'current_status', v_event.status
    );
  END IF;

  -- Server-side guard: countdown must have expired
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

  IF v_player_count >= v_min_players THEN

    v_configured_winners := CASE
      WHEN v_player_count < 6  THEN 1
      WHEN v_player_count < 11 THEN 2
      ELSE 3
    END;

    UPDATE public.events
    SET status = 'active',
        configured_winners = v_configured_winners
    WHERE id = p_event_id
      AND status = 'pending';

    RETURN jsonb_build_object(
      'success', true,
      'event_id', p_event_id,
      'players_count', v_player_count
    );

  ELSE

    -- Not enough players → delete the event
    DELETE FROM public.events
    WHERE id = p_event_id
      AND status = 'pending';

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
-- 3. Trigger: auto-activate only automated events when room fills
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
  SELECT id, status, type, max_participants, is_automated
  INTO v_event
  FROM public.events
  WHERE id = NEW.event_id;

  -- Only automated online events in pending state
  IF NOT FOUND
     OR NOT v_event.is_automated
     OR v_event.type != 'online'
     OR v_event.status != 'pending' THEN
    RETURN NEW;
  END IF;

  -- Count all non-spectator, non-banned players for this event
  SELECT COUNT(*) INTO v_player_count
  FROM public.game_players
  WHERE event_id = NEW.event_id
    AND status NOT IN ('spectator', 'banned');

  -- Room full → activate immediately
  IF v_player_count >= v_event.max_participants THEN
    v_configured_winners := CASE
      WHEN v_player_count < 6  THEN 1
      WHEN v_player_count < 11 THEN 2
      ELSE 3
    END;

    UPDATE public.events
    SET status = 'active',
        configured_winners = v_configured_winners
    WHERE id = NEW.event_id
      AND status = 'pending';
  END IF;

  RETURN NEW;
END;
$$;

-- Recreate trigger (idempotent)
DROP TRIGGER IF EXISTS trg_check_online_event_room_full ON public.game_players;

CREATE TRIGGER trg_check_online_event_room_full
AFTER INSERT ON public.game_players
FOR EACH ROW
EXECUTE FUNCTION public.check_online_event_room_full();

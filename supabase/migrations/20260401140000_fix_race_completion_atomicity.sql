-- ============================================================================
-- MIGRATION: Fix Active→Completed race completion atomicity
--
-- BUGS FIXED:
--   1. verify_and_complete_minigame drops raceCompleted/eventId from
--      submit_clue_answer → handshake path never triggers register_race_finisher.
--   2. register_race_finisher allows p_user_id spoofing (no auth.uid() check).
--   3. Redundant trigger trg_sync_final_placement_on_event_completed duplicates
--      distribute_event_prizes work inside the same transaction.
--   4. distribute_event_prizes has no idempotency marker for 0-pot events.
--   5. Stuck state: user marked completed but distribute_event_prizes fails
--      internally → event stays active, all subsequent calls short-circuit.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 1: verify_and_complete_minigame — propagate full submit_clue_answer response
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.verify_and_complete_minigame(uuid, text, jsonb, text, boolean);

CREATE OR REPLACE FUNCTION public.verify_and_complete_minigame(
  p_session_id uuid,
  p_answer text DEFAULT '',
  p_result jsonb DEFAULT '{}'::jsonb,
  p_ip_hash text DEFAULT NULL,
  p_challenge_valid boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_session RECORD;
  v_elapsed_seconds integer;
  v_min_seconds integer;
  v_response jsonb;
  v_past_flags integer;
  v_block_interval interval;
  v_opaque_error constant text := '0xERR-992A-4B';
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reference_code', '0xERR-AUTH');
  END IF;

  SELECT * INTO v_session FROM public.minigame_sessions
  WHERE id = p_session_id AND user_id = v_user_id;

  IF NOT FOUND OR v_session.is_completed THEN
    RETURN jsonb_build_object('success', false, 'reference_code', v_opaque_error);
  END IF;

  -- Challenge validation: reject if session has a challenge but caller didn't validate it
  IF v_session.challenge_hash IS NOT NULL AND p_challenge_valid IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'reference_code', '0xERR-CHALLENGE');
  END IF;

  -- Escalating ban: past flags → permanent, first offense → 5 minutes
  SELECT COUNT(*) INTO v_past_flags
  FROM public.minigame_sessions
  WHERE user_id = v_user_id AND is_flagged = true AND id != p_session_id;
  IF v_past_flags > 0 THEN v_block_interval := interval '200 years';
  ELSE v_block_interval := interval '5 minutes';
  END IF;

  -- Session expiry check
  IF v_session.expires_at < now() THEN
    UPDATE public.minigame_sessions SET is_flagged = true WHERE id = p_session_id;

    IF coalesce(p_ip_hash, v_session.ip_hash) IS NOT NULL THEN
      INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason)
      VALUES (v_user_id, coalesce(p_ip_hash, v_session.ip_hash), now() + v_block_interval, 'session_expired')
      ON CONFLICT (ip_hash)
      DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + v_block_interval);
    END IF;

    RETURN jsonb_build_object('success', false, 'reference_code', v_opaque_error);
  END IF;

  -- Minimum duration check (anti-cheat)
  v_elapsed_seconds := floor(extract(epoch from (now() - v_session.start_time)));
  v_min_seconds := v_session.min_duration_seconds;

  IF v_elapsed_seconds < v_min_seconds THEN
    UPDATE public.minigame_sessions SET is_flagged = true WHERE id = p_session_id;

    IF coalesce(p_ip_hash, v_session.ip_hash) IS NOT NULL THEN
      INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason)
      VALUES (v_user_id, coalesce(p_ip_hash, v_session.ip_hash), now() + v_block_interval, 'too_fast')
      ON CONFLICT (ip_hash)
      DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + v_block_interval);
    END IF;

    INSERT INTO public.admin_alerts (type, user_id, clue_id, session_id, payload)
    VALUES (
      'minigame_too_fast',
      v_user_id,
      v_session.clue_id,
      v_session.id,
      jsonb_build_object(
        'elapsed_seconds', v_elapsed_seconds,
        'min_duration_seconds', v_min_seconds,
        'ip_hash', coalesce(p_ip_hash, v_session.ip_hash),
        'past_flags_detected', v_past_flags
      )
    );

    RETURN jsonb_build_object(
      'success', false,
      'error', 'TOO_FAST',
      'flagged', true,
      'elapsed_seconds', v_elapsed_seconds,
      'min_duration_seconds', v_min_seconds,
      'reference_code', v_opaque_error
    );
  END IF;

  -- Mark session completed
  UPDATE public.minigame_sessions
  SET is_completed = true, is_flagged = false, ip_hash = coalesce(p_ip_hash, v_session.ip_hash)
  WHERE id = p_session_id;

  -- Call submit_clue_answer and PROPAGATE the full response (raceCompleted, eventId, etc.)
  v_response := public.submit_clue_answer(v_session.clue_id, coalesce(p_answer, ''));

  -- FIX: Return the FULL submit_clue_answer response merged with success flag.
  -- Previously only coins_earned was returned, dropping raceCompleted and eventId.
  RETURN jsonb_build_object(
    'success',        true,
    'coins_earned',   (v_response->>'coins_earned')::int,
    'new_balance',    (v_response->>'new_balance')::int,
    'raceCompleted',  COALESCE((v_response->>'raceCompleted')::boolean, false),
    'eventId',        v_response->>'eventId'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_and_complete_minigame(uuid, text, jsonb, text, boolean) TO service_role;


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 3: Drop redundant trigger (distribute_event_prizes already handles this)
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_sync_final_placement_on_event_completed ON public.events;
DROP FUNCTION IF EXISTS public.sync_final_placement_on_event_completed();


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 4: distribute_event_prizes — idempotency for 0-pot + reorder operations
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.distribute_event_prizes(p_event_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_event_record RECORD;
  v_required_winners INT;
  v_participant_count INT;
  v_completed_count INT;
  v_distributable_pot NUMERIC;
  v_total_collected NUMERIC;
  v_winners RECORD;
  v_prize_amount NUMERIC;
  v_share NUMERIC;
  v_rank INT;
  v_distribution_results JSONB[] := ARRAY[]::JSONB[];
  v_shares NUMERIC[];
  v_winner_user_id UUID;
  v_betting_result JSONB;
BEGIN
  -- 1. Lock Event & Get Details
  SELECT * INTO v_event_record FROM events WHERE id = p_event_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  -- Normalize configured winners to a safe range [1..3]
  v_required_winners := LEAST(GREATEST(COALESCE(v_event_record.configured_winners, 1), 1), 3);

  -- 2. Idempotency Check (covers BOTH paid and 0-pot events)
  IF EXISTS (SELECT 1 FROM prize_distributions WHERE event_id = p_event_id) THEN
     RETURN json_build_object('success', true, 'message', 'Premios ya distribuidos previamente', 'race_completed', true, 'already_distributed', true);
  END IF;

  -- 2.5 Secondary idempotency: if event is already completed, return
  IF v_event_record.status = 'completed' THEN
     RETURN json_build_object('success', true, 'message', 'Evento ya completado', 'race_completed', true, 'already_distributed', true);
  END IF;

  -- 3. Define Distribution Shares
  IF v_required_winners = 1 THEN
    v_shares := ARRAY[1.0];
  ELSIF v_required_winners = 2 THEN
    v_shares := ARRAY[0.70, 0.30];
  ELSE
    v_shares := ARRAY[0.50, 0.30, 0.20];
  END IF;

  -- 4. Count ALL Participants (excludes spectators)
  SELECT COUNT(*) INTO v_participant_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status IN ('active', 'completed', 'banned', 'suspended', 'eliminated');

  IF v_participant_count = 0 THEN
    RETURN json_build_object('success', false, 'message', 'No hay participantes validos');
  END IF;

  -- 4.5 Permission check for early force-close
  SELECT COUNT(*) INTO v_completed_count
  FROM game_players WHERE event_id = p_event_id AND status = 'completed';

  IF v_completed_count < v_required_winners AND v_completed_count < v_participant_count THEN
    IF (auth.role() != 'service_role') AND (NOT public.is_admin(auth.uid())) THEN
        RETURN json_build_object('success', false, 'message', 'La carrera aun no ha terminado o no tienes permisos para forzar la distribucion.');
    END IF;
  END IF;

  -- ═══════════════════════════════════════════════════════════════════════
  -- PHASE 1: Assign placements and mark all players completed FIRST
  -- (Before setting event status, to avoid Realtime firing prematurely)
  -- ═══════════════════════════════════════════════════════════════════════

  -- 5. Assign final_placement to ALL non-spectator participants
  UPDATE game_players gp
  SET final_placement = ranked.pos
  FROM (
    SELECT id,
      ROW_NUMBER() OVER (
        ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST, last_active ASC NULLS LAST
      ) AS pos
    FROM game_players
    WHERE event_id = p_event_id
      AND status != 'spectator'
  ) AS ranked
  WHERE gp.id = ranked.id;

  -- 5.5 Mark all active non-spectator players as completed for consistency
  UPDATE game_players
  SET status = 'completed'
  WHERE event_id = p_event_id
    AND status = 'active';

  -- ═══════════════════════════════════════════════════════════════════════
  -- PHASE 2: Calculate and distribute prizes
  -- ═══════════════════════════════════════════════════════════════════════

  -- 6. Calculate Pot
  v_total_collected := COALESCE(v_event_record.pot, 0);
  v_distributable_pot := v_total_collected * 0.70;

  -- Determine the overall #1 winner (for bets and event.winner_id)
  SELECT user_id INTO v_winner_user_id
  FROM game_players
  WHERE event_id = p_event_id AND status != 'spectator'
  ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
  LIMIT 1;

  IF v_distributable_pot <= 0 THEN
      -- FIX: Insert idempotency marker even for 0-pot events
      INSERT INTO prize_distributions
        (event_id, user_id, position, amount, pot_total, participants_count, entry_fee, rpc_success)
      VALUES
        (p_event_id, v_winner_user_id, 1, 0, 0, v_participant_count, COALESCE(v_event_record.entry_fee, 0), true);

      -- Resolve bets even with 0-pot
      IF v_winner_user_id IS NOT NULL THEN
          v_betting_result := public.resolve_event_bets(p_event_id, v_winner_user_id);
      END IF;

      -- PHASE 3: Finalize event status LAST (triggers Realtime AFTER all data is consistent)
      UPDATE events
      SET status = 'completed',
          completed_at = NOW(),
          winner_id = v_winner_user_id
      WHERE id = p_event_id;

      RETURN json_build_object(
        'success', true,
        'message', 'Evento finalizado sin premios (Bote 0)',
        'pot', 0,
        'betting_results', v_betting_result
      );
  END IF;

  -- 7. Select Winners (Top N) and distribute prizes
  v_rank := 0;

  FOR v_winners IN
    SELECT *
    FROM game_players
    WHERE event_id = p_event_id
    AND status = 'completed'
    ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
    LIMIT v_required_winners
  LOOP
    v_rank := v_rank + 1;

    IF v_rank = 1 THEN
       v_winner_user_id := v_winners.user_id;
    END IF;

    IF v_rank <= array_length(v_shares, 1) THEN
        v_share := v_shares[v_rank];
        v_prize_amount := floor(v_distributable_pot * v_share);

        IF v_prize_amount > 0 THEN
            -- A. Update User Wallet
            UPDATE profiles
            SET clovers = COALESCE(clovers, 0) + v_prize_amount
            WHERE id = v_winners.user_id;

            -- B. Record Distribution Log (also serves as idempotency marker)
            INSERT INTO prize_distributions
            (event_id, user_id, position, amount, pot_total, participants_count, entry_fee, rpc_success)
            VALUES
            (p_event_id, v_winners.user_id, v_rank, v_prize_amount, v_distributable_pot, v_participant_count, v_event_record.entry_fee, true);

            -- C. Log to Wallet Ledger
            INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
            VALUES (
              v_winners.user_id,
              v_prize_amount,
              'Premio Competencia: ' || v_event_record.title || ' (Posicion ' || v_rank || ')',
              jsonb_build_object('type', 'event_prize', 'event_id', p_event_id, 'rank', v_rank)
            );

            -- D. Add to results
            v_distribution_results := array_append(v_distribution_results, jsonb_build_object(
                'user_id', v_winners.user_id,
                'rank', v_rank,
                'amount', v_prize_amount
            ));
        END IF;
    END IF;
  END LOOP;

  -- 8. Resolve bets with #1 winner
  IF v_winner_user_id IS NOT NULL THEN
      v_betting_result := public.resolve_event_bets(p_event_id, v_winner_user_id);
  ELSE
      v_betting_result := jsonb_build_object('success', false, 'message', 'No winner found to resolve bets');
  END IF;

  -- ═══════════════════════════════════════════════════════════════════════
  -- PHASE 3: Finalize event status LAST
  -- This triggers Realtime AFTER all prizes, placements, and bets are committed.
  -- ═══════════════════════════════════════════════════════════════════════
  UPDATE events
  SET status = 'completed',
      completed_at = NOW(),
      winner_id = v_winner_user_id
  WHERE id = p_event_id;

  RETURN json_build_object(
    'success', true,
    'pot_total', v_total_collected,
    'distributable_pot', v_distributable_pot,
    'winners_count', v_rank,
    'results', v_distribution_results,
    'betting_results', v_betting_result
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$;


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 2 + 5: register_race_finisher — auth validation + stuck state recovery
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.register_race_finisher(p_event_id uuid, p_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_event_status text;
  v_configured_winners int;
  v_required_winners int;
  v_total_participants int;
  v_winners_count int;
  v_user_status text;
  v_position int;
  v_prize_amount int;
  v_current_placement int;
  v_distribution_result json;
BEGIN
  -- ═══════════════════════════════════════════════════════════════════════
  -- FIX: Security validation — prevent user spoofing
  -- Service role and admins can register on behalf of any user.
  -- Regular users can only register themselves.
  -- ═══════════════════════════════════════════════════════════════════════
  IF auth.role() != 'service_role' THEN
    IF auth.uid() IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'No autorizado');
    END IF;
    IF auth.uid() != p_user_id AND NOT public.is_admin(auth.uid()) THEN
      RETURN json_build_object('success', false, 'message', 'No autorizado: solo puedes registrar tu propia finalizacion');
    END IF;
  END IF;

  -- A. Lock Event
  SELECT status, configured_winners
  INTO v_event_status, v_configured_winners
  FROM events
  WHERE id = p_event_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  -- Normalize configured winners to at least 1
  v_required_winners := GREATEST(COALESCE(v_configured_winners, 1), 1);

  -- B. Validate User Status
  SELECT status, final_placement INTO v_user_status, v_current_placement
  FROM game_players
  WHERE event_id = p_event_id AND user_id = p_user_id;

  -- FIX: If user is already completed AND event is also completed, return cached result
  IF v_user_status = 'completed' AND v_event_status = 'completed' THEN
     SELECT amount INTO v_prize_amount
     FROM prize_distributions
     WHERE event_id = p_event_id AND user_id = p_user_id;

     RETURN json_build_object(
        'success', true,
        'message', 'Ya has completado esta carrera',
        'position', v_current_placement,
        'prize', COALESCE(v_prize_amount, 0),
        'race_completed', true
     );
  END IF;

  -- FIX: Stuck state recovery — user marked completed but event still active
  -- (happens if distribute_event_prizes failed internally on a previous call)
  IF v_user_status = 'completed' AND v_event_status != 'completed' THEN
     -- Re-count winners to determine position
     SELECT COUNT(*) INTO v_winners_count
     FROM game_players WHERE event_id = p_event_id AND status = 'completed';

     SELECT COUNT(*) INTO v_total_participants
     FROM game_players WHERE event_id = p_event_id AND status IN ('active', 'completed');

     IF v_winners_count >= v_required_winners OR v_winners_count >= v_total_participants THEN
       -- Re-attempt distribution
       SELECT public.distribute_event_prizes(p_event_id) INTO v_distribution_result;

       SELECT amount INTO v_prize_amount
       FROM prize_distributions
       WHERE event_id = p_event_id AND user_id = p_user_id;

       RETURN json_build_object(
          'success', true,
          'position', COALESCE(v_current_placement, v_winners_count),
          'prize', COALESCE(v_prize_amount, 0),
          'race_completed', COALESCE((v_distribution_result->>'success')::boolean, false)
       );
     END IF;

     -- Not enough finishers yet, just return current position
     RETURN json_build_object(
        'success', true,
        'position', COALESCE(v_current_placement, v_winners_count),
        'prize', 0,
        'race_completed', false
     );
  END IF;

  -- If event already completed and user is NOT completed, mark them late
  IF v_event_status = 'completed' THEN
     SELECT COUNT(*) INTO v_winners_count
     FROM game_players WHERE event_id = p_event_id AND status = 'completed';
     v_position := v_winners_count + 1;

     UPDATE game_players
     SET status = 'completed',
         finish_time = NOW(),
         final_placement = v_position,
         completed_clues_count = (SELECT COUNT(*) FROM clues WHERE event_id = p_event_id)
     WHERE event_id = p_event_id AND user_id = p_user_id;

     RETURN json_build_object('success', true, 'position', v_position, 'prize', 0, 'race_completed', true);
  END IF;

  IF v_user_status != 'active' THEN
     RETURN json_build_object('success', false, 'message', 'Usuario no activo en el evento');
  END IF;

  -- C. Count current winners
  SELECT COUNT(*) INTO v_winners_count
  FROM game_players
  WHERE event_id = p_event_id AND status = 'completed';

  -- If podium already full, trigger distribution as recovery
  IF v_winners_count >= v_required_winners THEN
     SELECT public.distribute_event_prizes(p_event_id) INTO v_distribution_result;
     RETURN json_build_object('success', false, 'message', 'Podio completo', 'race_completed', true);
  END IF;

  -- D. Calculate Position
  v_position := v_winners_count + 1;

  -- E. Register Completion with Position
  UPDATE game_players
  SET
    status = 'completed',
    finish_time = NOW(),
    completed_clues_count = (SELECT COUNT(*) FROM clues WHERE event_id = p_event_id),
    final_placement = v_position
  WHERE event_id = p_event_id AND user_id = p_user_id;

  -- F. Check if event should close (Podium Full OR Last Participant)
  SELECT COUNT(*) INTO v_total_participants
  FROM game_players
  WHERE event_id = p_event_id
  AND status IN ('active', 'completed');

  IF (v_position >= v_required_winners) OR (v_position >= v_total_participants) THEN
      -- Distribute prizes (handles event finalization, placements, prizes, AND bets)
      SELECT public.distribute_event_prizes(p_event_id) INTO v_distribution_result;

      IF COALESCE((v_distribution_result->>'success')::boolean, false) = false THEN
        RETURN json_build_object(
          'success', false,
          'message', COALESCE(v_distribution_result->>'message', 'Error finalizando el evento'),
          'position', v_position,
          'race_completed', false,
          'distribution_result', v_distribution_result
        );
      END IF;

      -- Retrieve prize for this user
      SELECT amount INTO v_prize_amount
      FROM prize_distributions
      WHERE event_id = p_event_id AND user_id = p_user_id;

      RETURN json_build_object(
        'success', true,
        'position', v_position,
        'prize', COALESCE(v_prize_amount, 0),
        'race_completed', true
      );
  END IF;

  -- Normal return (event not yet closed)
  RETURN json_build_object(
    'success', true,
    'position', v_position,
    'prize', 0,
    'race_completed', false
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$;


NOTIFY pgrst, 'reload schema';

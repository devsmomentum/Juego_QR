-- Fix race completion threshold handling when configured_winners is null/invalid.
-- Ensures events close correctly when configured_winners = 1.

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

  -- Betting integration
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

  -- 2. Idempotency Check
  IF EXISTS (SELECT 1 FROM prize_distributions WHERE event_id = p_event_id AND rpc_success = true) THEN
     RETURN json_build_object('success', true, 'message', 'Premios ya distribuidos previamente', 'race_completed', true, 'already_distributed', true);
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

  -- 4.5. Check if race is finished or if caller is admin
  SELECT COUNT(*) INTO v_completed_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status = 'completed';

  IF v_completed_count < v_required_winners AND v_completed_count < v_participant_count THEN
    IF (auth.role() != 'service_role') AND (NOT public.is_admin(auth.uid())) THEN
        RETURN json_build_object('success', false, 'message', 'La carrera aun no ha terminado o no tienes permisos para forzar la distribucion.');
    END IF;
  END IF;

  -- 5. Finalize Event (ALWAYS, even if pot is 0)
  UPDATE events
  SET status = 'completed',
      completed_at = NOW(),
      winner_id = (
        SELECT user_id
        FROM game_players
        WHERE event_id = p_event_id AND status != 'spectator'
        ORDER BY completed_clues_count DESC, finish_time ASC
        LIMIT 1
      )
  WHERE id = p_event_id;

  -- 6. Assign final_placement to ALL non-spectator participants (ALWAYS)
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

  -- 6.5 Mark active non-spectator players as completed for consistency
  UPDATE game_players
  SET status = 'completed'
  WHERE event_id = p_event_id
    AND status = 'active';

  -- 7. Calculate Pot
  v_total_collected := COALESCE(v_event_record.pot, 0);
  v_distributable_pot := v_total_collected * 0.70;

  IF v_distributable_pot <= 0 THEN
      -- Still resolve bets even if prize pot is 0
      SELECT user_id INTO v_winner_user_id
      FROM game_players
      WHERE event_id = p_event_id AND status != 'spectator'
      ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
      LIMIT 1;

      IF v_winner_user_id IS NOT NULL THEN
          v_betting_result := public.resolve_event_bets(p_event_id, v_winner_user_id);
      END IF;

      RETURN json_build_object(
        'success', true,
        'message', 'Evento finalizado sin premios (Bote 0)',
        'pot', 0,
        'betting_results', v_betting_result
      );
  END IF;

  -- 8. Select Winners (Top N) and distribute prizes
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

    -- Identify the #1 winner for betting resolution
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

            -- B. Record Distribution Log
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

  -- 9. Resolve bets with #1 winner
  IF v_winner_user_id IS NOT NULL THEN
      v_betting_result := public.resolve_event_bets(p_event_id, v_winner_user_id);
  ELSE
      v_betting_result := jsonb_build_object('success', false, 'message', 'No winner found to resolve bets');
  END IF;

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

  -- If already completed, return existing data
  IF v_user_status = 'completed' THEN
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

  -- If podium already full (race condition edge case), reject
  IF v_winners_count >= v_required_winners THEN
     UPDATE events SET status = 'completed', completed_at = NOW() WHERE id = p_event_id AND status != 'completed';
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

-- Data safety net for legacy rows with invalid values.
UPDATE events
SET configured_winners = 1
WHERE configured_winners IS NULL OR configured_winners < 1;

CREATE OR REPLACE FUNCTION public.sync_final_placement_on_event_completed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') THEN
    UPDATE game_players gp
    SET final_placement = ranked.pos
    FROM (
      SELECT id,
        ROW_NUMBER() OVER (
          ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST, last_active ASC NULLS LAST
        ) AS pos
      FROM game_players
      WHERE event_id = NEW.id
        AND status != 'spectator'
    ) AS ranked
    WHERE gp.id = ranked.id;

    UPDATE game_players
    SET status = 'completed'
    WHERE event_id = NEW.id
      AND status = 'active';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_final_placement_on_event_completed ON public.events;
CREATE TRIGGER trg_sync_final_placement_on_event_completed
AFTER UPDATE OF status ON public.events
FOR EACH ROW
EXECUTE FUNCTION public.sync_final_placement_on_event_completed();

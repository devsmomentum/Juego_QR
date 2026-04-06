-- =============================================================
-- Migration: User Bet Outcome RPC
-- Purpose:
-- Returns betting outcome summary for a user after an event completes.
-- Includes aggregate context (pool, winners, payout per ticket) while
-- respecting RLS by using SECURITY DEFINER.
-- =============================================================

CREATE OR REPLACE FUNCTION public.get_user_bet_outcome(
    p_event_id uuid,
    p_user_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_event RECORD;
    v_total_pool INTEGER := 0;
    v_total_winning_tickets INTEGER := 0;
    v_user_bets_count INTEGER := 0;
    v_user_winning_tickets INTEGER := 0;
    v_user_winnings INTEGER := 0;
    v_net_profit INTEGER := 0;
    v_commission_pct INTEGER := 0;
    v_commission INTEGER := 0;
    v_distributable INTEGER := 0;
    v_payout_per_ticket INTEGER := 0;
    v_dust INTEGER := 0;
    v_runner_commission INTEGER := 0;
    v_is_resolved BOOLEAN := FALSE;
    v_scenario TEXT := 'no_bets';
BEGIN
    SELECT id, winner_id, bet_ticket_price, COALESCE(runner_bet_commission_pct, 10) AS runner_bet_commission_pct
    INTO v_event
    FROM public.events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Event not found');
    END IF;

    SELECT COALESCE(SUM(amount), 0)::INT
    INTO v_total_pool
    FROM public.bets
    WHERE event_id = p_event_id;

    SELECT COUNT(*)::INT
    INTO v_total_winning_tickets
    FROM public.bets
    WHERE event_id = p_event_id
      AND racer_id = v_event.winner_id;

    SELECT COUNT(*)::INT
    INTO v_user_winning_tickets
    FROM public.bets
    WHERE event_id = p_event_id
      AND racer_id = v_event.winner_id
      AND user_id = p_user_id;

        SELECT COUNT(*)::INT
        INTO v_user_bets_count
        FROM public.bets
        WHERE event_id = p_event_id
            AND user_id = p_user_id;

    SELECT COALESCE(SUM(amount), 0)::INT
    INTO v_user_winnings
    FROM public.wallet_ledger
    WHERE user_id = p_user_id
      AND (metadata->>'type') = 'bet_payout'
      AND (metadata->>'event_id') = p_event_id::text;

    SELECT EXISTS(
        SELECT 1
        FROM public.wallet_ledger
        WHERE (metadata->>'event_id') = p_event_id::text
          AND (metadata->>'type') IN ('bet_payout', 'runner_bet_commission')
        LIMIT 1
    )
    INTO v_is_resolved;

        SELECT COALESCE(SUM(amount), 0)::INT
        INTO v_runner_commission
        FROM public.wallet_ledger
        WHERE (metadata->>'type') = 'runner_bet_commission'
            AND (metadata->>'event_id') = p_event_id::text;

    v_commission_pct := v_event.runner_bet_commission_pct;

    IF v_total_pool = 0 THEN
        v_scenario := 'no_bets';
        v_payout_per_ticket := 0;
    ELSIF v_total_winning_tickets = 0 THEN
        v_scenario := 'house_win';
        v_payout_per_ticket := 0;
    ELSE
        v_net_profit := v_total_pool - (v_total_winning_tickets * v_event.bet_ticket_price);

        IF v_net_profit <= 0 THEN
            v_scenario := 'unanimous';
            v_payout_per_ticket := v_event.bet_ticket_price;
            v_dust := v_total_pool - (v_payout_per_ticket * v_total_winning_tickets);
        ELSE
            v_scenario := 'normal';
            v_commission := FLOOR(v_net_profit * v_commission_pct / 100.0)::INT;
            v_distributable := v_total_pool - v_commission;
            v_payout_per_ticket := FLOOR(v_distributable::NUMERIC / v_total_winning_tickets)::INT;
            v_dust := v_distributable - (v_payout_per_ticket * v_total_winning_tickets);
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'event_id', p_event_id,
        'winner_id', v_event.winner_id,
        'total_pool', v_total_pool,
        'total_winning_tickets', v_total_winning_tickets,
        'payout_per_ticket', v_payout_per_ticket,
        'runner_commission', v_runner_commission,
        'commission_pct', v_commission_pct,
        'user_bets_count', v_user_bets_count,
        'user_winning_tickets', v_user_winning_tickets,
        'user_winnings', v_user_winnings,
        'won', (v_user_winning_tickets > 0),
        'is_resolved', v_is_resolved,
        'scenario', v_scenario
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

ALTER FUNCTION public.get_user_bet_outcome(uuid, uuid) OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.get_user_bet_outcome(uuid, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_user_bet_outcome(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_bet_outcome(uuid, uuid) TO service_role;

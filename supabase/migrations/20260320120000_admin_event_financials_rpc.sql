-- =============================================================
-- Migration: Admin Event Financials RPC
-- Purpose: 
-- Create a SECURITY DEFINER RPC that returns all financial data
-- for a completed event, bypassing RLS restrictions on
-- prize_distributions and wallet_ledger tables.
-- This is needed because the admin panel cannot read other users'
-- prize_distributions or wallet_ledger entries due to RLS policies.
-- =============================================================

CREATE OR REPLACE FUNCTION public.get_admin_event_financials(p_event_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_event RECORD;
    v_podium JSONB;
    v_bettors JSONB;
    v_betting_pot BIGINT;
BEGIN
    -- SECURITY: Only admins can call this
    IF NOT public.is_admin(auth.uid()) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- 1. Get event data
    SELECT pot, configured_winners, winner_id, title
    INTO v_event
    FROM events WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Event not found');
    END IF;

    -- 2. Build podium from prize_distributions + wallet_ledger commissions
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'user_id', pd.user_id,
            'name', COALESCE(pr.name, 'Usuario'),
            'avatar_id', pr.avatar_id,
            'rank', pd.position,
            'amount', pd.amount,
            'commission', COALESCE(comm.total_commission, 0)
        ) ORDER BY pd.position
    ), '[]'::jsonb)
    INTO v_podium
    FROM prize_distributions pd
    LEFT JOIN profiles pr ON pr.id = pd.user_id
    LEFT JOIN (
        SELECT wl.user_id, SUM(wl.amount)::INT AS total_commission
        FROM wallet_ledger wl
        WHERE wl.metadata->>'type' = 'runner_bet_commission'
          AND wl.metadata->>'event_id' = p_event_id::TEXT
        GROUP BY wl.user_id
    ) comm ON comm.user_id = pd.user_id
    WHERE pd.event_id = p_event_id AND pd.rpc_success = true;

    -- 2b. Fallback: if no prize_distributions, build from game_players
    IF v_podium = '[]'::jsonb THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'user_id', gp.user_id,
                'name', COALESCE(pr.name, 'Usuario'),
                'avatar_id', pr.avatar_id,
                'rank', gp.final_placement,
                'amount', 0,
                'commission', COALESCE(comm.total_commission, 0)
            ) ORDER BY gp.final_placement
        ), '[]'::jsonb)
        INTO v_podium
        FROM game_players gp
        LEFT JOIN profiles pr ON pr.id = gp.user_id
        LEFT JOIN (
            SELECT wl.user_id, SUM(wl.amount)::INT AS total_commission
            FROM wallet_ledger wl
            WHERE wl.metadata->>'type' = 'runner_bet_commission'
              AND wl.metadata->>'event_id' = p_event_id::TEXT
            GROUP BY wl.user_id
        ) comm ON comm.user_id = gp.user_id
        WHERE gp.event_id = p_event_id
          AND gp.final_placement IS NOT NULL
          AND gp.status != 'spectator'
        ORDER BY gp.final_placement
        LIMIT 3;
    END IF;

    -- 3. Get betting pot total
    SELECT COALESCE(SUM(amount), 0) INTO v_betting_pot
    FROM bets WHERE event_id = p_event_id;

    -- 4. Build bettors list with individual bets and winnings
    SELECT COALESCE(jsonb_agg(bettor_data ORDER BY (bettor_data->>'total_won')::INT DESC), '[]'::jsonb)
    INTO v_bettors
    FROM (
        SELECT jsonb_build_object(
            'user_id', b_agg.user_id,
            'name', COALESCE(pr.name, 'Apostador'),
            'avatar_id', pr.avatar_id,
            'total_bet', b_agg.total_bet,
            'total_won', COALESCE(wl_agg.total_won, 0),
            'bets_count', b_agg.bets_count,
            'net', COALESCE(wl_agg.total_won, 0) - b_agg.total_bet,
            'individual_bets', b_agg.individual_bets
        ) AS bettor_data
        FROM (
            -- Aggregate bets per user with individual bet details
            SELECT 
                b.user_id,
                SUM(b.amount)::INT AS total_bet,
                COUNT(*)::INT AS bets_count,
                jsonb_agg(
                    jsonb_build_object(
                        'racer_id', b.racer_id,
                        'racer_name', COALESCE(racer_pr.name, 'Jugador'),
                        'amount', b.amount,
                        'won', (b.racer_id = v_event.winner_id)
                    )
                ) AS individual_bets
            FROM bets b
            LEFT JOIN profiles racer_pr ON racer_pr.id = b.racer_id
            WHERE b.event_id = p_event_id
            GROUP BY b.user_id
        ) b_agg
        LEFT JOIN profiles pr ON pr.id = b_agg.user_id
        LEFT JOIN (
            -- Aggregate bet payouts per user from wallet_ledger
            SELECT wl.user_id, SUM(wl.amount)::INT AS total_won
            FROM wallet_ledger wl
            WHERE wl.metadata->>'type' = 'bet_payout'
              AND wl.metadata->>'event_id' = p_event_id::TEXT
            GROUP BY wl.user_id
        ) wl_agg ON wl_agg.user_id = b_agg.user_id
    ) sub;

    RETURN jsonb_build_object(
        'success', true,
        'pot', FLOOR(COALESCE(v_event.pot, 0) * 0.70)::INT,
        'betting_pot', v_betting_pot,
        'winner_id', v_event.winner_id,
        'podium', v_podium,
        'bettors', v_bettors
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

ALTER FUNCTION public.get_admin_event_financials(UUID) OWNER TO postgres;

-- Grant access to authenticated users (function itself checks is_admin)
GRANT EXECUTE ON FUNCTION public.get_admin_event_financials(UUID) TO authenticated;

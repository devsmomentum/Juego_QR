-- Migration to add store_prices and update buy_item
-- This allows per-event pricing for the global store items.

-- 1. Add column to events table
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS store_prices JSONB DEFAULT '{}'::jsonb;

-- 2. Update buy_item RPC
CREATE OR REPLACE FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean DEFAULT true, "p_game_player_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_game_player_id UUID;
    v_current_coins BIGINT;
    v_current_clovers BIGINT;
    v_new_balance BIGINT;
    v_power_id UUID;
    v_current_qty INT;
    v_player_status TEXT;
    v_spectator_config JSONB;
    v_store_prices JSONB;
    v_final_cost INT;
    v_is_spectator BOOLEAN := FALSE;
BEGIN
    -- 1. Resolve Game Player ID & Status
    IF p_game_player_id IS NOT NULL THEN
        SELECT id, status INTO v_game_player_id, v_player_status
        FROM public.game_players
        WHERE id = p_game_player_id;
    ELSE
        SELECT id, status INTO v_game_player_id, v_player_status
        FROM public.game_players
        WHERE user_id = p_user_id AND event_id = p_event_id
        LIMIT 1;
    END IF;

    IF v_game_player_id IS NULL THEN
        RAISE EXCEPTION 'Player not found in this event';
    END IF;

    -- Determine if Spectator
    IF v_player_status = 'spectator' THEN
        v_is_spectator := TRUE;
    END IF;

    -- 2. DETERMINE COST
    v_final_cost := p_cost;
    
    -- Fetch event-specific pricing
    SELECT store_prices, spectator_config INTO v_store_prices, v_spectator_config
    FROM public.events
    WHERE id = p_event_id;
    
    -- PRIORITY 1: store_prices (Global Event Prices for all roles)
    IF v_store_prices IS NOT NULL AND (v_store_prices->>p_item_id) IS NOT NULL THEN
        v_final_cost := (v_store_prices->>p_item_id)::INT;
    -- PRIORITY 2: spectator_config (Legacy/Specific for Spectators)
    ELSIF v_is_spectator AND v_spectator_config IS NOT NULL AND (v_spectator_config->>p_item_id) IS NOT NULL THEN
        v_final_cost := (v_spectator_config->>p_item_id)::INT;
    END IF;

    -- 3. Check Funds
    IF v_is_spectator THEN
        -- SPECTATORS: Pay with CLOVERS from PROFILES
        SELECT clovers INTO v_current_clovers
        FROM public.profiles
        WHERE id = p_user_id;

        IF v_current_clovers IS NULL THEN v_current_clovers := 0; END IF;

        IF v_current_clovers < v_final_cost THEN
            RAISE EXCEPTION 'Insufficient clovers. Required: %, Available: %', v_final_cost, v_current_clovers;
        END IF;
    ELSE
        -- PLAYERS: Pay with COINS from GAME_PLAYERS
        SELECT coins INTO v_current_coins
        FROM public.game_players
        WHERE id = v_game_player_id;

        IF v_current_coins IS NULL THEN 
            v_current_coins := 100; 
            UPDATE public.game_players SET coins = 100 WHERE id = v_game_player_id;
        END IF;

        IF v_current_coins < v_final_cost THEN
            RAISE EXCEPTION 'Insufficient coins. Required: %, Available: %', v_final_cost, v_current_coins;
        END IF;
    END IF;

    -- 4. Inventory Logic
    IF p_item_id = 'extra_life' THEN
         UPDATE public.game_players
         SET lives = LEAST(lives + 1, 3)
         WHERE id = v_game_player_id;
         
    ELSIF p_is_power THEN
        -- Find Power ID by slug
        SELECT id INTO v_power_id FROM public.powers WHERE slug = p_item_id LIMIT 1;
        
        IF v_power_id IS NULL THEN
            RAISE EXCEPTION 'Power not found: %', p_item_id;
        END IF;

        -- Upsert logic for player_powers
        SELECT quantity INTO v_current_qty 
        FROM public.player_powers 
        WHERE game_player_id = v_game_player_id AND power_id = v_power_id 
        LIMIT 1;
        
        IF v_current_qty IS NOT NULL THEN
             UPDATE public.player_powers 
             SET quantity = quantity + 1 
             WHERE game_player_id = v_game_player_id AND power_id = v_power_id;
        ELSE
             INSERT INTO public.player_powers (game_player_id, power_id, quantity)
             VALUES (v_game_player_id, v_power_id, 1);
        END IF;
    END IF;

    -- 5. Deduct Method (Split by Role)
    IF v_is_spectator THEN
       v_new_balance := v_current_clovers - v_final_cost;
       UPDATE public.profiles
       SET clovers = v_new_balance
       WHERE id = p_user_id;
    ELSE
       v_new_balance := v_current_coins - v_final_cost;
       UPDATE public.game_players
       SET coins = v_new_balance
       WHERE id = v_game_player_id;
    END IF;

    -- 6. Record Transaction
    INSERT INTO public.transactions (id, game_player_id, transaction_type, coins_change, description)
    VALUES (gen_random_uuid(), v_game_player_id, 'purchase', -v_final_cost, 'Purchase ' || p_item_id || (CASE WHEN v_is_spectator THEN ' (Spec)' ELSE '' END));

    RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance, 'cost_deducted', v_final_cost);
END;
$$;

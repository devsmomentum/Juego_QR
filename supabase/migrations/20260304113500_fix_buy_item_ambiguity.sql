-- Migration to resolve buy_item RPC ambiguity
-- This drops the old version of the function that had an extra p_store_id parameter.

DROP FUNCTION IF EXISTS public.buy_item(
    p_user_id uuid, 
    p_event_id uuid, 
    p_item_id text, 
    p_cost integer, 
    p_is_power boolean, 
    p_game_player_id uuid, 
    p_store_id uuid
);

-- Ensure the new version has correct permissions (redundant but safe)
GRANT EXECUTE ON FUNCTION public.buy_item(uuid, uuid, text, integer, boolean, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.buy_item(uuid, uuid, text, integer, boolean, uuid) TO service_role;

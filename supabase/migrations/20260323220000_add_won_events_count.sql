-- =============================================================
-- Migration: Add won_events_count to profiles
-- Purpose: 
--   Track the number of events a user has won (1st place)
--   using a denormalized counter for O(1) reads on profile.
--   Maintained atomically via trigger on game_players.
-- =============================================================

-- =============================================
-- STEP 1: Add the column
-- =============================================
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS won_events_count integer DEFAULT 0 NOT NULL;

COMMENT ON COLUMN public.profiles.won_events_count IS 
  'Denormalized counter of events won (1st place). Maintained by trigger on game_players.';

-- =============================================
-- STEP 2: Backfill from historical data
-- Uses prize_distributions (position = 1) as 
-- source of truth for past winners.
-- Falls back to game_players.final_placement = 1
-- for events where prize_distributions may not exist.
-- =============================================
UPDATE public.profiles p
SET won_events_count = COALESCE(wins.total, 0)
FROM (
  SELECT user_id, COUNT(DISTINCT event_id) AS total
  FROM (
    -- Source 1: prize_distributions (most reliable)
    SELECT user_id, event_id
    FROM public.prize_distributions
    WHERE position = 1 AND rpc_success = true
    
    UNION
    
    -- Source 2: game_players with final_placement = 1 (fallback)
    SELECT gp.user_id, gp.event_id
    FROM public.game_players gp
    INNER JOIN public.events e ON e.id = gp.event_id
    WHERE gp.final_placement = 1
      AND e.status = 'completed'
  ) AS combined_wins
  GROUP BY user_id
) wins
WHERE p.id = wins.user_id;

-- =============================================
-- STEP 3: Trigger Function
-- Fires AFTER UPDATE on game_players.
-- Increments when a player gets final_placement = 1.
-- Decrements if admin removes the 1st place (corrects).
-- =============================================
CREATE OR REPLACE FUNCTION public.sync_won_events_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Case 1: Player just got assigned 1st place
  IF (NEW.final_placement = 1) AND 
     (OLD.final_placement IS DISTINCT FROM 1) THEN
    UPDATE public.profiles
    SET won_events_count = COALESCE(won_events_count, 0) + 1
    WHERE id = NEW.user_id;
  END IF;

  -- Case 2: Player lost 1st place (admin correction)
  IF (OLD.final_placement = 1) AND 
     (NEW.final_placement IS DISTINCT FROM 1) THEN
    UPDATE public.profiles
    SET won_events_count = GREATEST(COALESCE(won_events_count, 0) - 1, 0)
    WHERE id = OLD.user_id;
  END IF;

  RETURN NEW;
END;
$$;

-- =============================================
-- STEP 4: Create Trigger
-- =============================================
DROP TRIGGER IF EXISTS trg_sync_won_events_count ON public.game_players;

CREATE TRIGGER trg_sync_won_events_count
AFTER UPDATE OF final_placement ON public.game_players
FOR EACH ROW
EXECUTE FUNCTION public.sync_won_events_count();

-- =============================================
-- STEP 5: RLS — won_events_count is readable  
-- by the owner via existing profile RLS policies.
-- No additional policies needed since profiles
-- already has SELECT policies for authenticated users.
-- =============================================

-- Update the public view to include won_events_count
CREATE OR REPLACE VIEW public.profiles_public AS
SELECT 
  id,
  name,
  avatar_id,
  level,
  total_xp,
  profession,
  won_events_count
FROM public.profiles;

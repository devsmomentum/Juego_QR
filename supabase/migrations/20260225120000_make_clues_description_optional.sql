-- Migration: Make clues.description fully optional
-- Date: 2025-02-25
-- Purpose: The 'description' field is no longer used as a player-facing hint.
--          Instead, the 'hint' field (ubicación) of the NEXT clue in sequence
--          is shown to players after completing a minigame.
--          This migration ensures 'description' has a safe default and is not required.

-- The column already has a DEFAULT, but let's ensure it allows NULL for new inserts
-- that don't provide it at all, and update the default to empty string.
ALTER TABLE public.clues
  ALTER COLUMN description SET DEFAULT '';

-- Optionally: Update existing rows that still have the placeholder text
UPDATE public.clues
  SET description = ''
  WHERE description = 'Descripción pendiente';

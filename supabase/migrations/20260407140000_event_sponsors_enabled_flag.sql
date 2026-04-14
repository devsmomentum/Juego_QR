-- ============================================================================
-- Migration: Add sponsors_enabled boolean to events
-- Replaces the old 1:1 sponsor_id approach with a simple boolean flag.
-- When true, the app loads the sponsor pool from event_sponsors table.
-- ============================================================================

ALTER TABLE "public"."events"
    ADD COLUMN IF NOT EXISTS "sponsors_enabled" boolean DEFAULT false;

-- Backfill: events that had a sponsor_id get sponsors_enabled = true
UPDATE "public"."events"
SET sponsors_enabled = true
WHERE sponsor_id IS NOT NULL;

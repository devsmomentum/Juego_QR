-- =============================================================================
-- MIGRATION: Scheduled Mode for Online Event Automation
-- =============================================================================
-- Extends the `online_automation_config` JSON to support two modes:
--
--   "automatic" (default): events created every `interval_minutes` since
--                          the last one. Ignores `scheduled_hours`.
--
--   "scheduled": events created at fixed UTC hours from `scheduled_hours`.
--                Ignores `interval_minutes`. The event is created when
--                current_time == scheduled_hour - pending_wait_minutes.
--
-- Only one mode can be active at a time. The Edge Function reads `mode`
-- and branches accordingly.
--
-- NEW JSON FIELDS:
--   mode             TEXT    "automatic" | "scheduled"  (default: "automatic")
--   scheduled_hours  TEXT[]  e.g. ["10:00", "16:00", "22:00"]  (VET / UTC-4)
--
-- EXISTING FIELDS ARE PRESERVED — no destructive changes.
-- =============================================================================

-- 1. Add `mode` and `scheduled_hours` defaults to existing config
--    (only if they don't already exist, to be idempotent)
UPDATE public.app_config
SET value = value
    || CASE WHEN NOT (value ? 'mode') THEN '{"mode": "automatic"}'::jsonb ELSE '{}'::jsonb END
    || CASE WHEN NOT (value ? 'scheduled_hours') THEN '{"scheduled_hours": []}'::jsonb ELSE '{}'::jsonb END,
    updated_at = now()
WHERE key = 'online_automation_config'
  AND NOT (value ? 'mode' AND value ? 'scheduled_hours');

-- =============================================================================
-- EXAMPLE: Full config after migration
-- =============================================================================
-- {
--   "enabled": false,
--   "mode": "automatic",
--   "scheduled_hours": [],
--   "max_fee": 0,
--   "min_fee": 0,
--   "fee_step": 5,
--   "max_games": 13,
--   "min_games": 6,
--   "max_players": 60,
--   "min_players": 5,
--   "player_prices": { "invisibility": 50 },
--   "interval_minutes": 59,
--   "spectator_prices": { "black_screen": 80 },
--   "min_players_to_start": 5,
--   "pending_wait_minutes": 20
-- }
-- =============================================================================

-- =============================================================================
-- TEST QUERY: Switch to scheduled mode with sample hours
-- =============================================================================
-- UPDATE public.app_config
-- SET value = value
--     || '{"mode": "scheduled", "scheduled_hours": ["14:00", "20:00"]}'::jsonb,
--     updated_at = now()
-- WHERE key = 'online_automation_config';
-- =============================================================================

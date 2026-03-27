-- Migration: toggle for minigame min-duration checks

INSERT INTO public.app_config (key, value, description, updated_at, updated_by)
VALUES (
  'minigame_min_duration_enabled',
  'true'::jsonb,
  'Enable/disable minigame min-duration checks',
  now(),
  'system'
)
ON CONFLICT (key) DO NOTHING;

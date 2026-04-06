-- Migration: add minigame min-duration config (seconds by difficulty)

INSERT INTO public.app_config (key, value, description, updated_at, updated_by)
VALUES (
  'minigame_min_duration_by_difficulty',
  '{"easy":4,"medium":8,"hard":12}'::jsonb,
  'Min duration (seconds) by minigame difficulty',
  now(),
  'system'
)
ON CONFLICT (key) DO NOTHING;

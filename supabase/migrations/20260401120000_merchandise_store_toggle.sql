-- ============================================================
-- Migration: Add merchandise_store_enabled toggle in app_config
-- Purpose: Allow admins to show/hide the Tienda tab for all users.
--          Defaults to FALSE (hidden) until explicitly enabled.
-- ============================================================

-- 1. Seed the config key (fail-safe: disabled by default)
INSERT INTO public.app_config (key, value, description, updated_at, updated_by)
VALUES (
  'merchandise_store_enabled',
  'false'::jsonb,
  'Controls visibility of the Tienda (merchandise store) tab on the home screen. Only admins can toggle.',
  now(),
  'system'
)
ON CONFLICT (key) DO NOTHING;

-- 2. Secure RPC: toggle_merchandise_store
--    - SECURITY DEFINER to bypass RLS
--    - Validates caller is admin via profiles.role
--    - Returns the new value for confirmation
CREATE OR REPLACE FUNCTION public.toggle_merchandise_store(p_enabled boolean)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
BEGIN
  -- Security check: only admins can call this
  SELECT role INTO v_caller_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Forbidden: only admins can toggle the merchandise store';
  END IF;

  -- Update the config
  UPDATE public.app_config
  SET value = to_jsonb(p_enabled),
      updated_at = now(),
      updated_by = auth.uid()::text
  WHERE key = 'merchandise_store_enabled';

  -- If the row didn't exist, insert it
  IF NOT FOUND THEN
    INSERT INTO public.app_config (key, value, description, updated_at, updated_by)
    VALUES ('merchandise_store_enabled', to_jsonb(p_enabled), 'Tienda visibility toggle', now(), auth.uid()::text);
  END IF;

  RETURN p_enabled;
END;
$$;

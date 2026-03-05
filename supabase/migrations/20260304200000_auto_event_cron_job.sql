-- =============================================================================
-- AUTO ONLINE EVENT CRON JOB
-- =============================================================================
-- Registers a pg_cron job that fires every minute as a "base tick".
-- The actual event creation interval is controlled dynamically by the
-- `interval_minutes` value in `app_config` (key = 'online_automation_config').
-- The Edge Function `automate-online-events` already handles the check:
--   it reads `interval_minutes` from config and skips creation if not enough
--   time has passed since the last online event.
--
-- REQUIRED VAULT SECRETS (add via Supabase Dashboard → Vault):
--   Name: automate_func_url
--   Value: https://<your-project-ref>.supabase.co/functions/v1/automate-online-events
--
--   Name: automate_func_key
--   Value: <your service_role JWT key>
-- =============================================================================

-- 1. Function that calls the Edge Function via pg_net (same pattern as trigger_bcv_update)
CREATE OR REPLACE FUNCTION "public"."trigger_auto_online_event"()
RETURNS "void"
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
DECLARE
  v_url        text;
  v_key        text;
  v_enabled    boolean;
  v_req_id     bigint;
BEGIN
  -- 1a. Fast-exit: skip if automation is disabled (avoids unnecessary HTTP call)
  SELECT (value ->> 'enabled')::boolean
  INTO v_enabled
  FROM public.app_config
  WHERE key = 'online_automation_config';

  IF v_enabled IS NOT TRUE THEN
    RETURN;
  END IF;

  -- 1b. Read Edge Function URL and service key from Vault
  SELECT decrypted_secret INTO v_url
  FROM vault.decrypted_secrets
  WHERE name = 'automate_func_url';

  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets
  WHERE name = 'automate_func_key';

  IF v_url IS NULL OR v_key IS NULL THEN
    RAISE WARNING '[trigger_auto_online_event] Vault secrets not found. Skipping.';
    RETURN;
  END IF;

  -- 1c. Call the Edge Function asynchronously via pg_net
  SELECT net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := '{}'::jsonb
  ) INTO v_req_id;

END;
$$;

ALTER FUNCTION "public"."trigger_auto_online_event"() OWNER TO "postgres";

-- 2. Schedule the cron tick (every minute as base clock)
--    The Edge Function checks interval_minutes internally and self-throttles.
SELECT cron.schedule(
  'auto-online-event-tick',           -- job name (unique)
  '* * * * *',                        -- every minute — Edge Fn handles the real interval
  'SELECT public.trigger_auto_online_event();'
);

-- To unschedule (if needed):
-- SELECT cron.unschedule('auto-online-event-tick');

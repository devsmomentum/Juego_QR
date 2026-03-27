-- Migration: auto-ban trigger for repeated minigame flags + TTL cleanup job

-- Config defaults (safe)
INSERT INTO public.app_config (key, value, description, updated_at, updated_by)
VALUES
  ('minigame_flag_threshold', to_jsonb(3), 'Flags required to trigger block', now(), 'system'),
  ('minigame_flag_window_minutes', to_jsonb(30), 'Window (minutes) to count flags', now(), 'system'),
  ('minigame_block_minutes', to_jsonb(30), 'Block duration in minutes after flag threshold', now(), 'system')
ON CONFLICT (key) DO NOTHING;

-- Function: handle minigame flag threshold
CREATE OR REPLACE FUNCTION public.handle_minigame_flag_threshold()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_threshold integer;
  v_window_minutes integer;
  v_block_minutes integer;
  v_flag_count integer;
  v_ip_hash text;
BEGIN
  -- Only act on new flags
  IF NEW.is_flagged IS DISTINCT FROM TRUE THEN
    RETURN NEW;
  END IF;
  IF OLD.is_flagged IS TRUE THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF((value #>> '{}'), ''), '3')::int
  INTO v_threshold
  FROM public.app_config
  WHERE key = 'minigame_flag_threshold';

  SELECT COALESCE(NULLIF((value #>> '{}'), ''), '30')::int
  INTO v_window_minutes
  FROM public.app_config
  WHERE key = 'minigame_flag_window_minutes';

  SELECT COALESCE(NULLIF((value #>> '{}'), ''), '30')::int
  INTO v_block_minutes
  FROM public.app_config
  WHERE key = 'minigame_block_minutes';

  v_threshold := GREATEST(COALESCE(v_threshold, 3), 1);
  v_window_minutes := GREATEST(COALESCE(v_window_minutes, 30), 1);
  v_block_minutes := GREATEST(COALESCE(v_block_minutes, 30), 1);

  SELECT COUNT(*)
  INTO v_flag_count
  FROM public.minigame_sessions
  WHERE user_id = NEW.user_id
    AND is_flagged = true
    AND start_time >= now() - (v_window_minutes || ' minutes')::interval;

  IF v_flag_count >= v_threshold THEN
    v_ip_hash := coalesce(NEW.ip_hash, NULL);

    IF v_ip_hash IS NOT NULL THEN
      INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason)
      VALUES (NEW.user_id, v_ip_hash, now() + (v_block_minutes || ' minutes')::interval, 'flag_threshold')
      ON CONFLICT (ip_hash)
      DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + (v_block_minutes || ' minutes')::interval),
                    user_id = EXCLUDED.user_id,
                    reason = EXCLUDED.reason;
    END IF;

    INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason)
    VALUES (NEW.user_id, v_ip_hash, now() + (v_block_minutes || ' minutes')::interval, 'flag_threshold')
    ON CONFLICT (user_id)
    DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + (v_block_minutes || ' minutes')::interval),
                  ip_hash = coalesce(EXCLUDED.ip_hash, minigame_abuse_blocks.ip_hash),
                  reason = EXCLUDED.reason;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS minigame_flag_threshold_trigger ON public.minigame_sessions;
CREATE TRIGGER minigame_flag_threshold_trigger
AFTER UPDATE OF is_flagged ON public.minigame_sessions
FOR EACH ROW
EXECUTE FUNCTION public.handle_minigame_flag_threshold();

-- Optional TTL cleanup: remove old sessions after expiration (safe)
CREATE OR REPLACE FUNCTION public.purge_expired_minigame_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.minigame_sessions
  WHERE expires_at < now() - interval '1 hour';
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'minigame-session-cleanup'
  ) THEN
    PERFORM cron.schedule(
      'minigame-session-cleanup',
      '*/15 * * * *',
      'select public.purge_expired_minigame_sessions();'
    );
  END IF;
END $$;

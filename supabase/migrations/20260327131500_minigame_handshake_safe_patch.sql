-- Safe patch for minigame handshake (idempotent)

-- Ensure table exists
CREATE TABLE IF NOT EXISTS public.minigame_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  clue_id bigint NOT NULL REFERENCES public.clues(id) ON DELETE CASCADE,
  start_time timestamptz NOT NULL DEFAULT now(),
  is_completed boolean NOT NULL DEFAULT false,
  min_duration_seconds integer NOT NULL CHECK (min_duration_seconds >= 0),
  is_flagged boolean NOT NULL DEFAULT false
);

-- Add columns safely
ALTER TABLE public.minigame_sessions
  ADD COLUMN IF NOT EXISTS expires_at timestamptz NOT NULL DEFAULT (now() + interval '10 minutes');

ALTER TABLE public.minigame_sessions
  ADD COLUMN IF NOT EXISTS ip_hash text;

ALTER TABLE public.minigame_sessions
  ADD COLUMN IF NOT EXISTS result_jsonb jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Indexes (safe)
CREATE INDEX IF NOT EXISTS idx_minigame_sessions_user_id ON public.minigame_sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_minigame_sessions_clue_id ON public.minigame_sessions (clue_id);
CREATE INDEX IF NOT EXISTS idx_minigame_sessions_start_time ON public.minigame_sessions (start_time);
CREATE INDEX IF NOT EXISTS idx_minigame_sessions_expires_at ON public.minigame_sessions (expires_at);
CREATE INDEX IF NOT EXISTS idx_minigame_sessions_ip_hash ON public.minigame_sessions (ip_hash);

ALTER TABLE public.minigame_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "minigame_sessions_select_own" ON public.minigame_sessions;
CREATE POLICY "minigame_sessions_select_own"
ON public.minigame_sessions
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "minigame_sessions_service_role_all" ON public.minigame_sessions;
CREATE POLICY "minigame_sessions_service_role_all"
ON public.minigame_sessions
FOR ALL
USING ((auth.jwt()->>'role') = 'service_role')
WITH CHECK ((auth.jwt()->>'role') = 'service_role');

-- Config: TTL for minigame sessions (seconds)
INSERT INTO public.app_config (key, value, description, updated_at, updated_by)
VALUES (
  'minigame_session_ttl_seconds',
  to_jsonb(600),
  'TTL (seconds) for minigame sessions',
  now(),
  'system'
)
ON CONFLICT (key) DO NOTHING;

-- Abuse blocks table (safe)
CREATE TABLE IF NOT EXISTS public.minigame_abuse_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ip_hash text,
  blocked_until timestamptz NOT NULL,
  reason text NOT NULL DEFAULT 'suspicious_timing',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS minigame_abuse_blocks_user_id_key
ON public.minigame_abuse_blocks (user_id);

CREATE UNIQUE INDEX IF NOT EXISTS minigame_abuse_blocks_ip_hash_key
ON public.minigame_abuse_blocks (ip_hash)
WHERE ip_hash IS NOT NULL;

ALTER TABLE public.minigame_abuse_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "minigame_abuse_blocks_service_role_all" ON public.minigame_abuse_blocks;
CREATE POLICY "minigame_abuse_blocks_service_role_all"
ON public.minigame_abuse_blocks
FOR ALL
USING ((auth.jwt()->>'role') = 'service_role')
WITH CHECK ((auth.jwt()->>'role') = 'service_role');

-- RLS hardening for game_players
DROP POLICY IF EXISTS "Enable update for own profile" ON public.game_players;
DROP POLICY IF EXISTS "Solo admins pueden actualizar game_players" ON public.game_players;
DROP POLICY IF EXISTS "service_role_update_game_players" ON public.game_players;

CREATE POLICY "service_role_update_game_players"
ON public.game_players
FOR UPDATE
USING ((auth.jwt()->>'role') = 'service_role')
WITH CHECK ((auth.jwt()->>'role') = 'service_role');

-- RPC: start_minigame (updated signature)
CREATE OR REPLACE FUNCTION public.start_minigame(
  p_clue_id bigint,
  p_min_duration_seconds integer,
  p_ip_hash text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_session_id uuid;
  v_ttl_seconds integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_min_duration_seconds IS NULL OR p_min_duration_seconds < 0 THEN
    RAISE EXCEPTION 'Invalid min_duration_seconds';
  END IF;

  SELECT COALESCE(NULLIF((value #>> '{}'), ''), '600')::int
  INTO v_ttl_seconds
  FROM public.app_config
  WHERE key = 'minigame_session_ttl_seconds';

  v_ttl_seconds := GREATEST(COALESCE(v_ttl_seconds, 600), 60);

  IF EXISTS (
    SELECT 1 FROM public.minigame_abuse_blocks
    WHERE user_id = v_user_id AND blocked_until > now()
  ) THEN
    RAISE EXCEPTION 'Blocked: user_id';
  END IF;

  IF p_ip_hash IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.minigame_abuse_blocks
    WHERE ip_hash = p_ip_hash AND blocked_until > now()
  ) THEN
    RAISE EXCEPTION 'Blocked: ip_hash';
  END IF;

  INSERT INTO public.minigame_sessions (user_id, clue_id, min_duration_seconds, ip_hash, expires_at)
  VALUES (
    v_user_id,
    p_clue_id,
    p_min_duration_seconds,
    p_ip_hash,
    now() + (v_ttl_seconds || ' seconds')::interval
  )
  RETURNING id INTO v_session_id;

  RETURN v_session_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_minigame(bigint, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_minigame(bigint, integer, text) TO service_role;

-- RPC: verify_and_complete_minigame (updated signature)
CREATE OR REPLACE FUNCTION public.verify_and_complete_minigame(
  p_session_id uuid,
  p_answer text DEFAULT '',
  p_result jsonb DEFAULT '{}'::jsonb,
  p_ip_hash text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_session RECORD;
  v_elapsed_seconds integer;
  v_min_seconds integer;
  v_response jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_session
  FROM public.minigame_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session not found');
  END IF;

  IF v_session.user_id <> v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Forbidden');
  END IF;

  IF v_session.is_completed THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session already completed');
  END IF;

  IF v_session.expires_at < now() THEN
    UPDATE public.minigame_sessions
    SET is_flagged = true,
        result_jsonb = coalesce(p_result, '{}'::jsonb)
    WHERE id = p_session_id;

    IF coalesce(p_ip_hash, v_session.ip_hash) IS NOT NULL THEN
      INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason)
      VALUES (v_user_id, coalesce(p_ip_hash, v_session.ip_hash), now() + interval '5 minutes', 'session_expired')
      ON CONFLICT (ip_hash)
      DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + interval '5 minutes'),
                    user_id = EXCLUDED.user_id,
                    reason = EXCLUDED.reason;
    END IF;

    INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason)
    VALUES (v_user_id, coalesce(p_ip_hash, v_session.ip_hash), now() + interval '5 minutes', 'session_expired')
    ON CONFLICT (user_id)
    DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + interval '5 minutes'),
                  ip_hash = coalesce(EXCLUDED.ip_hash, minigame_abuse_blocks.ip_hash),
                  reason = EXCLUDED.reason;

    RETURN jsonb_build_object('success', false, 'error', 'SESSION_EXPIRED');
  END IF;

  v_elapsed_seconds := floor(extract(epoch from (now() - v_session.start_time)));
  v_min_seconds := v_session.min_duration_seconds;

  IF v_elapsed_seconds < v_min_seconds THEN
    UPDATE public.minigame_sessions
    SET is_flagged = true,
        result_jsonb = coalesce(p_result, '{}'::jsonb)
    WHERE id = p_session_id;

    IF coalesce(p_ip_hash, v_session.ip_hash) IS NOT NULL THEN
      INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason)
      VALUES (v_user_id, coalesce(p_ip_hash, v_session.ip_hash), now() + interval '5 minutes', 'too_fast')
      ON CONFLICT (ip_hash)
      DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + interval '5 minutes'),
                    user_id = EXCLUDED.user_id,
                    reason = EXCLUDED.reason;
    END IF;

    INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason)
    VALUES (v_user_id, coalesce(p_ip_hash, v_session.ip_hash), now() + interval '5 minutes', 'too_fast')
    ON CONFLICT (user_id)
    DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + interval '5 minutes'),
                  ip_hash = coalesce(EXCLUDED.ip_hash, minigame_abuse_blocks.ip_hash),
                  reason = EXCLUDED.reason;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'TOO_FAST',
      'flagged', true,
      'elapsed_seconds', v_elapsed_seconds,
      'min_duration_seconds', v_min_seconds
    );
  END IF;

  UPDATE public.minigame_sessions
  SET is_completed = true,
      is_flagged = false,
      result_jsonb = coalesce(p_result, '{}'::jsonb),
      ip_hash = coalesce(p_ip_hash, v_session.ip_hash)
  WHERE id = p_session_id;

  v_response := public.submit_clue_answer(v_session.clue_id, coalesce(p_answer, ''));

  RETURN v_response || jsonb_build_object('elapsed_seconds', v_elapsed_seconds);
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_and_complete_minigame(uuid, text, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_and_complete_minigame(uuid, text, jsonb, text) TO service_role;

NOTIFY pgrst, 'reload schema';

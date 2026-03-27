-- Minigame server-side handshake (start/verify) + RLS hardening

-- 1) Session table for anti-replay and timing validation
CREATE TABLE IF NOT EXISTS public.minigame_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  clue_id bigint NOT NULL REFERENCES public.clues(id) ON DELETE CASCADE,
  start_time timestamptz NOT NULL DEFAULT now(),
  is_completed boolean NOT NULL DEFAULT false,
  min_duration_seconds integer NOT NULL CHECK (min_duration_seconds >= 0),
  is_flagged boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_minigame_sessions_user_id ON public.minigame_sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_minigame_sessions_clue_id ON public.minigame_sessions (clue_id);
CREATE INDEX IF NOT EXISTS idx_minigame_sessions_start_time ON public.minigame_sessions (start_time);

ALTER TABLE public.minigame_sessions ENABLE ROW LEVEL SECURITY;

-- Users can only read their own sessions (no direct writes; RPC only)
CREATE POLICY "minigame_sessions_select_own"
ON public.minigame_sessions
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- Service role can manage sessions (Edge Functions, backend jobs)
CREATE POLICY "minigame_sessions_service_role_all"
ON public.minigame_sessions
FOR ALL
USING ((auth.jwt()->>'role') = 'service_role')
WITH CHECK ((auth.jwt()->>'role') = 'service_role');

-- 2) RLS hardening: remove direct UPDATE from authenticated users on game_players
DROP POLICY IF EXISTS "Enable update for own profile" ON public.game_players;
DROP POLICY IF EXISTS "Solo admins pueden actualizar game_players" ON public.game_players;

CREATE POLICY "service_role_update_game_players"
ON public.game_players
FOR UPDATE
USING ((auth.jwt()->>'role') = 'service_role')
WITH CHECK ((auth.jwt()->>'role') = 'service_role');

-- 3) RPC: Start minigame session (handshake start)
CREATE OR REPLACE FUNCTION public.start_minigame(
  p_clue_id bigint,
  p_min_duration_seconds integer
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_session_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_min_duration_seconds IS NULL OR p_min_duration_seconds < 0 THEN
    RAISE EXCEPTION 'Invalid min_duration_seconds';
  END IF;

  INSERT INTO public.minigame_sessions (user_id, clue_id, min_duration_seconds)
  VALUES (v_user_id, p_clue_id, p_min_duration_seconds)
  RETURNING id INTO v_session_id;

  RETURN v_session_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_minigame(bigint, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_minigame(bigint, integer) TO service_role;

-- 4) RPC: Verify and complete minigame (handshake finish)
CREATE OR REPLACE FUNCTION public.verify_and_complete_minigame(
  p_session_id uuid,
  p_answer text DEFAULT '',
  p_result jsonb DEFAULT '{}'::jsonb
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

  v_elapsed_seconds := floor(extract(epoch from (now() - v_session.start_time)));
  v_min_seconds := v_session.min_duration_seconds;

  IF v_elapsed_seconds < v_min_seconds THEN
    UPDATE public.minigame_sessions
    SET is_flagged = true
    WHERE id = p_session_id;

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
      is_flagged = false
  WHERE id = p_session_id;

  -- Use the existing atomic progress RPC after validation.
  v_response := public.submit_clue_answer(v_session.clue_id, coalesce(p_answer, ''));

  RETURN v_response || jsonb_build_object('elapsed_seconds', v_elapsed_seconds);
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_and_complete_minigame(uuid, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_and_complete_minigame(uuid, text, jsonb) TO service_role;

NOTIFY pgrst, 'reload schema';

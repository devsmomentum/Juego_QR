-- ============================================================================
-- MIGRATION: Clean admin_alerts table + compatible verify_and_complete_minigame
-- Notes:
-- - Creates admin_alerts table and policies only (no legacy RPC override).
-- - Keeps current signature with challenge validation.
-- - Returns error 'TOO_FAST' for client clarity.
-- ============================================================================

-- 1) Admin alerts table + policies
CREATE TABLE IF NOT EXISTS public.admin_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  clue_id bigint REFERENCES public.clues(id) ON DELETE SET NULL,
  session_id uuid REFERENCES public.minigame_sessions(id) ON DELETE SET NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_alerts_created_at
ON public.admin_alerts (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_alerts_type
ON public.admin_alerts (type);

CREATE INDEX IF NOT EXISTS idx_admin_alerts_user_id
ON public.admin_alerts (user_id);

ALTER TABLE public.admin_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_alerts_admin_read" ON public.admin_alerts;
CREATE POLICY "admin_alerts_admin_read"
ON public.admin_alerts
FOR SELECT
USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "admin_alerts_service_role_all" ON public.admin_alerts;
CREATE POLICY "admin_alerts_service_role_all"
ON public.admin_alerts
FOR ALL
USING ((auth.jwt()->>'role') = 'service_role')
WITH CHECK ((auth.jwt()->>'role') = 'service_role');

-- 2) verify_and_complete_minigame (challenge + escalated bans + admin alert)
CREATE OR REPLACE FUNCTION public.verify_and_complete_minigame(
  p_session_id uuid,
  p_answer text DEFAULT '',
  p_result jsonb DEFAULT '{}'::jsonb,
  p_ip_hash text DEFAULT NULL,
  p_challenge_valid boolean DEFAULT false
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
  v_past_flags integer;
  v_block_interval interval;
  v_opaque_error constant text := '0xERR-992A-4B';
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reference_code', '0xERR-AUTH');
  END IF;

  SELECT * INTO v_session FROM public.minigame_sessions
  WHERE id = p_session_id AND user_id = v_user_id;

  IF NOT FOUND OR v_session.is_completed THEN
    RETURN jsonb_build_object('success', false, 'reference_code', v_opaque_error);
  END IF;

  -- Challenge validation: reject if session has a challenge but caller didn't validate it
  IF v_session.challenge_hash IS NOT NULL AND p_challenge_valid IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'reference_code', '0xERR-CHALLENGE');
  END IF;

  SELECT COUNT(*) INTO v_past_flags FROM public.minigame_sessions WHERE user_id = v_user_id AND is_flagged = true AND id != p_session_id;
  IF v_past_flags > 0 THEN v_block_interval := interval '200 years'; ELSE v_block_interval := interval '5 minutes'; END IF;

  IF v_session.expires_at < now() THEN
    UPDATE public.minigame_sessions SET is_flagged = true WHERE id = p_session_id;

    IF coalesce(p_ip_hash, v_session.ip_hash) IS NOT NULL THEN
      INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason)
      VALUES (v_user_id, coalesce(p_ip_hash, v_session.ip_hash), now() + v_block_interval, 'session_expired')
      ON CONFLICT (ip_hash)
      DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + v_block_interval);
    END IF;

    RETURN jsonb_build_object('success', false, 'reference_code', v_opaque_error);
  END IF;

  v_elapsed_seconds := floor(extract(epoch from (now() - v_session.start_time)));
  v_min_seconds := v_session.min_duration_seconds;

  IF v_elapsed_seconds < v_min_seconds THEN
    UPDATE public.minigame_sessions SET is_flagged = true WHERE id = p_session_id;

    IF coalesce(p_ip_hash, v_session.ip_hash) IS NOT NULL THEN
      INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason)
      VALUES (v_user_id, coalesce(p_ip_hash, v_session.ip_hash), now() + v_block_interval, 'too_fast')
      ON CONFLICT (ip_hash)
      DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + v_block_interval);
    END IF;

    INSERT INTO public.admin_alerts (type, user_id, clue_id, session_id, payload)
    VALUES (
      'minigame_too_fast',
      v_user_id,
      v_session.clue_id,
      v_session.id,
      jsonb_build_object(
        'elapsed_seconds', v_elapsed_seconds,
        'min_duration_seconds', v_min_seconds,
        'ip_hash', coalesce(p_ip_hash, v_session.ip_hash),
        'past_flags_detected', v_past_flags
      )
    );

    -- Return explicit TOO_FAST for client clarity
    RETURN jsonb_build_object(
      'success', false,
      'error', 'TOO_FAST',
      'flagged', true,
      'elapsed_seconds', v_elapsed_seconds,
      'min_duration_seconds', v_min_seconds,
      'reference_code', v_opaque_error
    );
  END IF;

  UPDATE public.minigame_sessions SET is_completed = true, is_flagged = false, ip_hash = coalesce(p_ip_hash, v_session.ip_hash) WHERE id = p_session_id;
  v_response := public.submit_clue_answer(v_session.clue_id, coalesce(p_answer, ''));

  RETURN jsonb_build_object('success', true, 'coins_earned', (v_response->>'coins_earned')::int);
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_and_complete_minigame(uuid, text, jsonb, text, boolean) TO service_role;

NOTIFY pgrst, 'reload schema';

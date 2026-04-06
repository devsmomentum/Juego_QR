-- Migration: admin alerts for minigame timing violations

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

-- Update verify_and_complete_minigame to log admin alerts when TOO_FAST
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

    INSERT INTO public.admin_alerts (type, user_id, clue_id, session_id, payload)
    VALUES (
      'minigame_too_fast',
      v_user_id,
      v_session.clue_id,
      v_session.id,
      jsonb_build_object(
        'elapsed_seconds', v_elapsed_seconds,
        'min_duration_seconds', v_min_seconds,
        'ip_hash', coalesce(p_ip_hash, v_session.ip_hash)
      )
    );

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

  RETURN jsonb_build_object(
    'success', true,
    'raceCompleted', v_response->>'raceCompleted',
    'raceCompletedGlobal', v_response->>'raceCompletedGlobal',
    'coins_earned', (v_response->>'coins_earned')::int
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_and_complete_minigame(uuid, text, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_and_complete_minigame(uuid, text, jsonb, text) TO service_role;

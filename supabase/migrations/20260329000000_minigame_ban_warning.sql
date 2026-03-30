-- ============================================================================
-- MIGRATION: Minigame Anti-Cheat — General Ban via profiles.status
-- Removes ALL references to minigame_abuse_blocks (table deleted).
-- Ban is now via profiles.status = 'banned'.
-- ============================================================================

-- 1) start_minigame: check profiles.status instead of abuse_blocks
CREATE OR REPLACE FUNCTION public.start_minigame(
  p_clue_id bigint,
  p_min_duration_seconds integer,
  p_ip_hash text DEFAULT NULL,
  p_challenge_hash text DEFAULT NULL,
  p_challenge_nonce text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_session_id uuid;
  v_ttl_seconds integer;
  v_profile_status text;
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

  -- Check general ban via profiles
  SELECT status INTO v_profile_status FROM public.profiles WHERE id = v_user_id;
  IF v_profile_status = 'banned' THEN
    RAISE EXCEPTION 'Blocked: user_id';
  END IF;

  INSERT INTO public.minigame_sessions (
    user_id, clue_id, min_duration_seconds, ip_hash, expires_at,
    challenge_hash, challenge_nonce
  )
  VALUES (
    v_user_id,
    p_clue_id,
    p_min_duration_seconds,
    p_ip_hash,
    now() + (v_ttl_seconds || ' seconds')::interval,
    p_challenge_hash,
    p_challenge_nonce
  )
  RETURNING id INTO v_session_id;

  RETURN v_session_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_minigame(bigint, integer, text, text, text) TO service_role;

-- 2) verify_and_complete_minigame: no abuse_blocks, ban via profiles.status
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
  v_is_admin boolean;
  v_should_ban boolean;
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

  -- Challenge validation
  IF v_session.challenge_hash IS NOT NULL AND p_challenge_valid IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'reference_code', '0xERR-CHALLENGE');
  END IF;

  SELECT COUNT(*) INTO v_past_flags
  FROM public.minigame_sessions
  WHERE user_id = v_user_id AND is_flagged = true AND id != p_session_id;

  SELECT public.is_admin(v_user_id) INTO v_is_admin;

  v_should_ban := (NOT v_is_admin) AND (v_past_flags > 0);

  -- ── Expired session ──
  IF v_session.expires_at < now() THEN
    UPDATE public.minigame_sessions SET is_flagged = true WHERE id = p_session_id;

    IF v_should_ban THEN
      UPDATE public.profiles SET status = 'banned' WHERE id = v_user_id;
    END IF;

    RETURN jsonb_build_object('success', false, 'reference_code', v_opaque_error);
  END IF;

  -- ── Too fast ──
  v_elapsed_seconds := floor(extract(epoch from (now() - v_session.start_time)));
  v_min_seconds := v_session.min_duration_seconds;

  IF v_elapsed_seconds < v_min_seconds THEN
    UPDATE public.minigame_sessions SET is_flagged = true WHERE id = p_session_id;

    IF v_should_ban THEN
      UPDATE public.profiles SET status = 'banned' WHERE id = v_user_id;
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
        'past_flags_detected', v_past_flags,
        'action_taken', CASE WHEN v_should_ban THEN 'banned_permanently' ELSE 'warned' END
      )
    );

    RETURN jsonb_build_object(
      'success', false,
      'error', CASE WHEN v_should_ban THEN 'TOO_FAST_BANNED' ELSE 'TOO_FAST_WARNING' END,
      'flagged', true,
      'elapsed_seconds', v_elapsed_seconds,
      'min_duration_seconds', v_min_seconds,
      'reference_code', v_opaque_error
    );
  END IF;

  -- ── Normal completion ──
  UPDATE public.minigame_sessions SET is_completed = true, is_flagged = false, ip_hash = coalesce(p_ip_hash, v_session.ip_hash) WHERE id = p_session_id;
  v_response := public.submit_clue_answer(v_session.clue_id, coalesce(p_answer, ''));

  RETURN jsonb_build_object('success', true, 'coins_earned', (v_response->>'coins_earned')::int);
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_and_complete_minigame(uuid, text, jsonb, text, boolean) TO service_role;

-- 3) get_minigame_block_status: check profiles.status instead of abuse_blocks
CREATE OR REPLACE FUNCTION public.get_minigame_block_status(
  p_ip_hash text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_profile_status text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('blocked', false, 'reason', 'Unauthorized');
  END IF;

  SELECT status INTO v_profile_status FROM public.profiles WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'blocked', v_profile_status = 'banned',
    'reason', CASE WHEN v_profile_status = 'banned' THEN 'banned_permanently' ELSE NULL END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_minigame_block_status(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_minigame_block_status(text) TO service_role;

-- 4) test_remove_my_ban: clear flags + reset profiles.status (admin only)
CREATE OR REPLACE FUNCTION public.test_remove_my_ban() RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Forbidden: admin only';
  END IF;

  UPDATE public.profiles SET status = 'active' WHERE id = auth.uid();
  DELETE FROM public.minigame_sessions WHERE user_id = auth.uid() AND is_flagged = true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.test_remove_my_ban() TO authenticated;
GRANT EXECUTE ON FUNCTION public.test_remove_my_ban() TO service_role;

NOTIFY pgrst, 'reload schema';

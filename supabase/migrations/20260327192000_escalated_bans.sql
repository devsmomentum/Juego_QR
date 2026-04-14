-- Escalated minigame bans, tracking history and adding admin simulation tool.
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

  SELECT COUNT(*) INTO v_past_flags FROM public.minigame_sessions WHERE user_id = v_user_id AND is_flagged = true AND id != p_session_id;
  IF v_past_flags > 0 THEN v_block_interval := interval '200 years'; ELSE v_block_interval := interval '5 minutes'; END IF;

  IF v_session.expires_at < now() THEN
    UPDATE public.minigame_sessions SET is_flagged = true WHERE id = p_session_id;
    
    IF coalesce(p_ip_hash, v_session.ip_hash) IS NOT NULL THEN
      INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason) VALUES (v_user_id, coalesce(p_ip_hash, v_session.ip_hash), now() + v_block_interval, 'session_expired') ON CONFLICT (ip_hash) DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + v_block_interval);
    END IF;
    
    RETURN jsonb_build_object('success', false, 'reference_code', v_opaque_error);
  END IF;

  v_elapsed_seconds := floor(extract(epoch from (now() - v_session.start_time)));
  v_min_seconds := v_session.min_duration_seconds;

  IF v_elapsed_seconds < v_min_seconds THEN
    UPDATE public.minigame_sessions SET is_flagged = true WHERE id = p_session_id;

    IF coalesce(p_ip_hash, v_session.ip_hash) IS NOT NULL THEN
      INSERT INTO public.minigame_abuse_blocks (user_id, ip_hash, blocked_until, reason) VALUES (v_user_id, coalesce(p_ip_hash, v_session.ip_hash), now() + v_block_interval, 'too_fast') ON CONFLICT (ip_hash) DO UPDATE SET blocked_until = GREATEST(minigame_abuse_blocks.blocked_until, now() + v_block_interval);
    END IF;

    -- Alerta interna para admins (sin enviarla al frente)
    INSERT INTO public.admin_alerts (type, user_id, clue_id, session_id, payload)
    VALUES ('minigame_too_fast', v_user_id, v_session.clue_id, v_session.id, jsonb_build_object('elapsed_seconds', v_elapsed_seconds, 'min_duration_seconds', v_min_seconds, 'ip_hash', coalesce(p_ip_hash, v_session.ip_hash), 'past_flags_detected', v_past_flags));

    RETURN jsonb_build_object('success', false, 'reference_code', v_opaque_error);
  END IF;

  UPDATE public.minigame_sessions SET is_completed = true, is_flagged = false, ip_hash = coalesce(p_ip_hash, v_session.ip_hash) WHERE id = p_session_id;
  v_response := public.submit_clue_answer(v_session.clue_id, coalesce(p_answer, ''));

  RETURN jsonb_build_object('success', true, 'coins_earned', (v_response->>'coins_earned')::int);
END;
$$;

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
  v_blocked_until timestamptz;
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

  -- Check user ban
  SELECT blocked_until INTO v_blocked_until
  FROM public.minigame_abuse_blocks
  WHERE user_id = v_user_id AND blocked_until > now()
  ORDER BY blocked_until DESC LIMIT 1;

  IF v_blocked_until IS NOT NULL THEN
    RAISE EXCEPTION 'Blocked: user_id|%', v_blocked_until;
  END IF;

  -- Check IP ban
  IF p_ip_hash IS NOT NULL THEN
    SELECT blocked_until INTO v_blocked_until
    FROM public.minigame_abuse_blocks
    WHERE ip_hash = p_ip_hash AND blocked_until > now()
    ORDER BY blocked_until DESC LIMIT 1;

    IF v_blocked_until IS NOT NULL THEN
      RAISE EXCEPTION 'Blocked: ip_hash|%', v_blocked_until;
    END IF;
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

-- New function for admin sim/unban
CREATE OR REPLACE FUNCTION public.test_remove_my_ban() RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Requires proper caller role.
  DELETE FROM public.minigame_abuse_blocks WHERE user_id = auth.uid();
  -- Purge the old session flags for this user so they don't get the 200 year ban instantly again
  DELETE FROM public.minigame_sessions WHERE user_id = auth.uid() AND is_flagged = true;
END;
$$;

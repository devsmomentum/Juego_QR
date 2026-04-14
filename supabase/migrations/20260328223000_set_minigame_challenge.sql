-- ============================================================================
-- MIGRATION: RPC to set minigame challenge hash/nonce safely
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_minigame_challenge(
  p_session_id uuid,
  p_challenge_hash text,
  p_challenge_nonce text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_session RECORD;
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

  UPDATE public.minigame_sessions
  SET
    challenge_hash = p_challenge_hash,
    challenge_nonce = coalesce(p_challenge_nonce, challenge_nonce)
  WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_minigame_challenge(uuid, text, text) TO service_role;

NOTIFY pgrst, 'reload schema';

-- Migration: RPC to check minigame block status

CREATE OR REPLACE FUNCTION public.get_minigame_block_status(
  p_ip_hash text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_block record;
  v_blocked_until timestamptz;
  v_reason text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('blocked', false, 'reason', 'Unauthorized');
  END IF;

  SELECT blocked_until, reason
  INTO v_blocked_until, v_reason
  FROM public.minigame_abuse_blocks
  WHERE user_id = v_user_id
    AND blocked_until > now()
  ORDER BY blocked_until DESC
  LIMIT 1;

  IF v_blocked_until IS NULL AND p_ip_hash IS NOT NULL THEN
    SELECT blocked_until, reason
    INTO v_blocked_until, v_reason
    FROM public.minigame_abuse_blocks
    WHERE ip_hash = p_ip_hash
      AND blocked_until > now()
    ORDER BY blocked_until DESC
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'blocked', v_blocked_until IS NOT NULL,
    'blocked_until', v_blocked_until,
    'reason', v_reason
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_minigame_block_status(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_minigame_block_status(text) TO service_role;

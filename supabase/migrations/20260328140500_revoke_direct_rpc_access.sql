-- ============================================================================
-- MIGRATION: Revoke direct authenticated access to sensitive RPCs
--
-- PROBLEM: submit_clue_answer, skip_clue_rpc, and test_remove_my_ban are
--          callable directly by any authenticated user, completely bypassing
--          the minigame handshake (timing checks, abuse blocks, flagging).
--
-- FIX: Revoke authenticated grants on scoring RPCs.
--      Internal calls from verify_and_complete_minigame (SECURITY DEFINER)
--      still work because the function owner has full privileges.
--      Admin-only wrapper RPCs are provided for admin tooling.
--      test_remove_my_ban is hardened with server-side admin check.
-- ============================================================================

-- 1) REVOKE direct access from authenticated users
REVOKE EXECUTE ON FUNCTION public.submit_clue_answer(BIGINT, TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.skip_clue_rpc(BIGINT) FROM authenticated;

-- Ensure service_role retains access (Edge Functions)
GRANT EXECUTE ON FUNCTION public.submit_clue_answer(BIGINT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.skip_clue_rpc(BIGINT) TO service_role;

-- 2) ADMIN-ONLY wrapper: submit_clue_answer
CREATE OR REPLACE FUNCTION public.admin_complete_clue(
  p_clue_id BIGINT,
  p_answer TEXT DEFAULT ''
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Forbidden: admin only');
  END IF;

  RETURN public.submit_clue_answer(p_clue_id, p_answer);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_complete_clue(BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_complete_clue(BIGINT, TEXT) TO service_role;

-- 3) ADMIN-ONLY wrapper: skip_clue_rpc
CREATE OR REPLACE FUNCTION public.admin_skip_clue(
  p_clue_id BIGINT
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Forbidden: admin only');
  END IF;

  RETURN public.skip_clue_rpc(p_clue_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_skip_clue(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_skip_clue(BIGINT) TO service_role;

-- 4) HARDEN test_remove_my_ban with server-side admin check
CREATE OR REPLACE FUNCTION public.test_remove_my_ban() RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Forbidden: admin only';
  END IF;

  DELETE FROM public.minigame_abuse_blocks WHERE user_id = auth.uid();
  DELETE FROM public.minigame_sessions WHERE user_id = auth.uid() AND is_flagged = true;
END;
$$;

-- Keep existing grants (function is now protected internally)
GRANT EXECUTE ON FUNCTION public.test_remove_my_ban() TO authenticated;
GRANT EXECUTE ON FUNCTION public.test_remove_my_ban() TO service_role;

NOTIFY pgrst, 'reload schema';

-- Create RPC to update current_session_id safely (bypasses missing UPDATE policy on profiles)
CREATE OR REPLACE FUNCTION public.set_current_session_id(p_session_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.profiles
  SET current_session_id = p_session_id
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_current_session_id(uuid) TO authenticated;

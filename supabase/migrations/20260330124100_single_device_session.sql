-- Add current_session_id to profiles to enforce Single Device Policy
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS current_session_id uuid;

-- Optional: Explicit policy for current_session_id (if column-level RLS is enabled or just general check)
-- In Supabase, usually row level security applies to the whole row. 
-- Assuming "Users can update own profile" already exists, we ensure they can update their session_id.
-- To explicitly satisfy "permit users to read their own current_session_id but block unauthorized", 
-- if they can view the row, they can view the column unless restricted.

-- Create RPC to validate session_id from request headers
CREATE OR REPLACE FUNCTION public.verify_session_id()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_header_token text;
  v_db_token uuid;
BEGIN
  -- If not authenticated, bypass
  IF auth.uid() IS NULL THEN
    RETURN true;
  END IF;

  v_header_token := current_setting('request.headers', true)::json->>'x-session-id';
  
  -- If no header is provided, we allow it by default so we don't break existing 
  -- edge cases (like Edge Functions) that haven't been updated to send it yet.
  IF v_header_token IS NULL THEN
    RETURN true; 
  END IF;

  SELECT current_session_id INTO v_db_token 
  FROM public.profiles 
  WHERE id = auth.uid();

  -- If the DB has no token yet, allow it.
  IF v_db_token IS NULL THEN
    RETURN true;
  END IF;

  -- Validate match
  RETURN v_db_token::text = v_header_token;
END;
$$;

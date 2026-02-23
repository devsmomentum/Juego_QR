-- Create a function to keep public.profiles.email_verified in sync with auth.users.email_confirmed_at
CREATE OR REPLACE FUNCTION public.sync_email_verification_status()
RETURNS TRIGGER AS $$
BEGIN
  -- When email_confirmed_at changes from NULL to a timestamp
  IF OLD.email_confirmed_at IS DISTINCT FROM NEW.email_confirmed_at THEN
    IF NEW.email_confirmed_at IS NOT NULL THEN
      UPDATE public.profiles
      SET email_verified = TRUE
      WHERE id = NEW.id;
    ELSE
      -- When email_confirmed_at changes from a timestamp to NULL
      UPDATE public.profiles
      SET email_verified = FALSE
      WHERE id = NEW.id;
    END IF;
  END IF;

  -- CRITICAL SECURITY FIX: 
  -- If a verified user changes their email address but Supabase leaves the old 
  -- email_confirmed_at timestamp untouched (common in single-factor setups),
  -- we must explicitly invalidate the session since it's a new unverified string.
  IF OLD.email IS DISTINCT FROM NEW.email AND OLD.email_confirmed_at IS NOT DISTINCT FROM NEW.email_confirmed_at THEN
     UPDATE public.profiles
     SET email_verified = FALSE
     WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on the auth.users table
DROP TRIGGER IF EXISTS on_auth_user_email_verification ON auth.users;
CREATE TRIGGER on_auth_user_email_verification
  AFTER UPDATE OF email_confirmed_at, email ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_email_verification_status();

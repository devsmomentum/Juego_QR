-- =============================================================================
-- ATOMIC REGISTRATION: handle_new_user trigger now creates a COMPLETE profile
-- from raw_user_meta_data, running inside the same transaction as auth.users INSERT.
-- If the profile INSERT fails (duplicate dni/phone, constraint violation, etc.),
-- the entire transaction rolls back — no orphan auth user is left behind.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = 'public'
AS $function$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    name,
    role,
    status,
    clovers,
    dni,
    phone
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'user'),
    'pending',
    0,
    NULLIF(NEW.raw_user_meta_data->>'cedula', ''),
    NULLIF(NEW.raw_user_meta_data->>'phone', '')
  );

  RETURN NEW;
END;
$function$;

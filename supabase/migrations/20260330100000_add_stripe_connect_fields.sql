-- Migración para añadir soporte a Stripe Connect en perfiles de usuario
-- Este script añade las columnas necesarias para almacenar el ID de cuenta conectada
-- y rastrear el estado del onboarding del usuario.

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS stripe_connect_id TEXT;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS stripe_onboarding_completed BOOLEAN DEFAULT FALSE;

-- Comentarios para documentación en el esquema
COMMENT ON COLUMN public.profiles.stripe_connect_id IS 'ID de la cuenta conectada de Stripe (Express) del usuario.';
COMMENT ON COLUMN public.profiles.stripe_onboarding_completed IS 'Indica si el usuario completó satisfactoriamente el flujo de registro en Stripe.';

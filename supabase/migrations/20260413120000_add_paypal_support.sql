-- Migration: Add PayPal support to user_payment_methods
-- Created at: 2026-04-13

-- 1. Update the check constraint for type to include 'paypal'
ALTER TABLE "public"."user_payment_methods"
DROP CONSTRAINT IF EXISTS "user_payment_methods_type_check",
ADD CONSTRAINT "user_payment_methods_type_check" 
CHECK ("type" IN ('pago_movil', 'stripe', 'paypal'));

-- 2. Update comments
COMMENT ON COLUMN "public"."user_payment_methods"."type" IS 'Type of payment method: pago_movil, stripe or paypal';
COMMENT ON COLUMN "public"."user_payment_methods"."identifier" IS 'Email address for Stripe/PayPal or other unique identifier for the method';

-- 3. Enable PayPal in app_config (if the configuration exists)
DO $$
DECLARE
  v_config jsonb;
BEGIN
  SELECT value INTO v_config
  FROM public.app_config
  WHERE key = 'payment_methods_status'
  LIMIT 1;

  IF v_config IS NOT NULL THEN
    -- Update the jsonb to enable paypal in the withdrawal flow
    v_config := jsonb_set(v_config, '{withdrawal, paypal}', 'true', true);
    
    UPDATE public.app_config
    SET value = v_config, updated_at = now()
    WHERE key = 'payment_methods_status';
  END IF;
END
$$;

-- ============================================================
-- Migration: Add payment methods status configuration
-- Purpose: Centralize purchase/withdrawal method toggles in app_config
-- ============================================================

-- Seed default config (fail-safe: all disabled until explicitly enabled)
INSERT INTO public.app_config (key, value, updated_at)
VALUES (
  'payment_methods_status',
  '{
    "purchase": {
      "pago_movil": false,
      "stripe": false,
      "zelle": false,
      "cash": false
    },
    "withdrawal": {
      "pago_movil": false,
      "stripe": false
    }
  }'::jsonb,
  now()
)
ON CONFLICT (key) DO NOTHING;

-- Helper: verify if a method is enabled for a given flow
CREATE OR REPLACE FUNCTION public.is_payment_method_enabled(
  p_flow text,
  p_method text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_config jsonb;
  v_enabled boolean;
BEGIN
  SELECT value INTO v_config
  FROM public.app_config
  WHERE key = 'payment_methods_status'
  LIMIT 1;

  IF v_config IS NULL THEN
    RETURN false;
  END IF;

  v_enabled := COALESCE((v_config -> p_flow ->> p_method)::boolean, false);
  RETURN v_enabled;
END;
$$;

-- Enforce purchase gateway validity at the DB level
CREATE OR REPLACE FUNCTION public.validate_clover_order_payment_method()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  -- Allow internal system writes regardless of config
  IF NEW.gateway = 'internal' THEN
    RETURN NEW;
  END IF;

  IF NOT public.is_payment_method_enabled('purchase', NEW.gateway) THEN
    RAISE EXCEPTION 'PAYMENT_METHOD_DISABLED: %', NEW.gateway;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_clover_order_payment_method
  ON public.clover_orders;

CREATE TRIGGER trg_validate_clover_order_payment_method
BEFORE INSERT OR UPDATE OF gateway ON public.clover_orders
FOR EACH ROW
EXECUTE FUNCTION public.validate_clover_order_payment_method();

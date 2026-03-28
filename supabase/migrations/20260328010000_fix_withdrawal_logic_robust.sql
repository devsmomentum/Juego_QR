-- Super Robust fix for withdrawal logic (Auto-repair table and functions)
-- Ensures withdrawal_requests table and its helper functions exist and work.
-- Safe: Use IF NOT EXISTS and CREATE OR REPLACE to avoid breaking anything.

-- 1. Ensure withdrawal_requests table exists (SAFE: does nothing if exists)
CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  plan_id uuid NOT NULL,
  payment_method_id uuid,
  gateway text NOT NULL,
  clovers_cost integer NOT NULL,
  amount_usd numeric NOT NULL,
  amount_ves numeric,
  bcv_rate numeric,
  status text NOT NULL DEFAULT 'pending',
  provider_data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT withdrawal_requests_status_check CHECK (status IN (
    'pending', 'completed', 'failed'
  ))
);

-- 2. Ensure RLS and basic safety (SAFE: idempotent)
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'withdrawal_requests' 
        AND policyname = 'withdrawal_requests_select_own'
    ) THEN
        CREATE POLICY withdrawal_requests_select_own
          ON public.withdrawal_requests
          FOR SELECT
          USING (auth.uid() = user_id);
    END IF;
END
$$;

GRANT SELECT ON public.withdrawal_requests TO authenticated;

-- 3. Optimization Indexes (SAFE: IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_user_id
  ON public.withdrawal_requests (user_id);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status
  ON public.withdrawal_requests (status);


-- 4. Helper: is_payment_method_enabled (SAFE: CREATE OR REPLACE)
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
    -- Fallback safety: let's assume methods are disabled until configured
    RETURN false;
  END IF;

  -- Use nested key extraction
  BEGIN
    v_enabled := COALESCE((v_config -> p_flow ->> p_method)::boolean, false);
  EXCEPTION WHEN OTHERS THEN
    v_enabled := false;
  END;

  RETURN v_enabled;
END;
$$;


-- 5. Main logic: create_withdrawal_request (SAFE: handle both methods)
CREATE OR REPLACE FUNCTION public.create_withdrawal_request(
  p_user_id uuid,
  p_plan_id uuid,
  p_payment_method_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_plan record;
  v_pm record;
  v_bcv_rate numeric;
  v_amount_ves numeric;
  v_request_id uuid;
  v_gateway text;
  v_rate_updated_at timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Missing user id';
  END IF;

  -- AUTHENTICATION
  IF (auth.role() != 'service_role') AND (auth.uid() != p_user_id) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 1. SELECT PLAN
  SELECT id, name, amount, price, is_active, type
  INTO v_plan
  FROM transaction_plans
  WHERE id = p_plan_id AND type = 'withdraw'
  LIMIT 1;

  IF v_plan.id IS NULL THEN
    RAISE EXCEPTION 'Plan de retiro no encontrado';
  END IF;

  IF v_plan.is_active IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'El plan de retiro seleccionado no esta disponible';
  END IF;

  -- 2. SELECT PAYMENT METHOD
  IF p_payment_method_id IS NOT NULL THEN
    SELECT *
    INTO v_pm
    FROM user_payment_methods
    WHERE id = p_payment_method_id AND user_id = p_user_id
    LIMIT 1;
  ELSE
    SELECT *
    INTO v_pm
    FROM user_payment_methods
    WHERE user_id = p_user_id
    ORDER BY is_default DESC, created_at DESC
    LIMIT 1;
  END IF;

  IF v_pm.id IS NULL THEN
    RAISE EXCEPTION 'Metodo de pago no encontrado. Por favor agrega uno primero.';
  END IF;

  v_gateway := COALESCE(v_pm.type, 'pago_movil');

  -- CHECK STATUS (Robust casting ::text)
  IF NOT public.is_payment_method_enabled('withdrawal'::text, v_gateway::text) THEN
    RAISE EXCEPTION 'Metodo de retiro deshabilitado: %', v_gateway;
  END IF;

  -- 3. BCV EXCHANGE RATE (ONLY for pago_movil)
  IF v_gateway = 'pago_movil' THEN
    SELECT (value)::numeric, updated_at
    INTO v_bcv_rate, v_rate_updated_at
    FROM app_config
    WHERE key = 'bcv_exchange_rate'
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_bcv_rate IS NULL OR v_bcv_rate <= 0 THEN
      RAISE EXCEPTION 'Tasa de cambio BCV no disponible';
    END IF;

    v_amount_ves := v_plan.price * v_bcv_rate;
  ELSE
    v_bcv_rate := NULL;
    v_amount_ves := NULL;
  END IF;

  -- 4. DEDUCT CLOVERS (Atomic Balance Lock)
  UPDATE profiles
  SET clovers = clovers - v_plan.amount
  WHERE id = p_user_id AND clovers >= v_plan.amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Saldo insuficiente de tréboles';
  END IF;

  -- 5. RECORD WITHDRAWAL
  INSERT INTO public.withdrawal_requests (
    user_id,
    plan_id,
    payment_method_id,
    gateway,
    clovers_cost,
    amount_usd,
    amount_ves,
    bcv_rate,
    status,
    provider_data,
    created_at,
    updated_at
  ) VALUES (
    p_user_id,
    v_plan.id,
    v_pm.id,
    v_gateway,
    v_plan.amount,
    v_plan.price,
    v_amount_ves,
    v_bcv_rate,
    'pending',
    jsonb_build_object(
      'bank_code', v_pm.bank_code,
      'dni', v_pm.dni,
      'phone_number', v_pm.phone_number,
      'stripe_email', v_pm.identifier
    ),
    now(),
    now()
  )
  RETURNING id INTO v_request_id;

  -- 6. LEDGER ENTRY
  INSERT INTO wallet_ledger (user_id, amount, description, metadata)
  VALUES (
    p_user_id,
    -v_plan.amount,
    'Retiro solicitado: ' || v_plan.name,
    jsonb_build_object(
      'type', 'withdrawal',
      'status', 'pending',
      'request_id', v_request_id::text,
      'plan_id', v_plan.id,
      'gateway', v_gateway,
      'amount_usd', v_plan.price,
      'amount_ves', v_amount_ves
    )
  );

  RETURN jsonb_build_object(
    'request_id', v_request_id,
    'gateway', v_gateway,
    'amount_usd', v_plan.price,
    'amount_ves', v_amount_ves,
    'status', 'pending'
  );
END;
$$;

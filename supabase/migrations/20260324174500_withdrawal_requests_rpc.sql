-- ============================================================
-- Migration: Atomic withdrawal requests + RPC workflow
-- Purpose: Ensure balance deduction + ledger logging are atomic
-- ============================================================

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

ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_user_id
  ON public.withdrawal_requests (user_id);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status
  ON public.withdrawal_requests (status);

DROP POLICY IF EXISTS withdrawal_requests_select_own ON public.withdrawal_requests;
CREATE POLICY withdrawal_requests_select_own
  ON public.withdrawal_requests
  FOR SELECT
  USING (auth.uid() = user_id);

GRANT SELECT ON public.withdrawal_requests TO authenticated;

-- ------------------------------------------------------------
-- RPC: Create withdrawal request (atomic)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS public.create_withdrawal_request(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.create_withdrawal_request(uuid, uuid, text);

CREATE OR REPLACE FUNCTION public.create_withdrawal_request(
  p_user_id uuid,
  p_plan_id uuid,
  p_payment_method_id text -- Changed from uuid to text for flexibility
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_plan record;
  v_pm record;
  v_profile record;
  v_bcv_rate numeric;
  v_amount_ves numeric;
  v_request_id uuid;
  v_gateway text;
  v_rate_updated_at timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Missing user id';
  END IF;

  IF (auth.role() != 'service_role') AND (auth.uid() != p_user_id) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

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

  -- Handle virtual 'stripe_connected_account' method or standard UUIDs
  IF p_payment_method_id = 'stripe_connected_account' THEN
    -- Virtual Stripe Connect automated method
    SELECT stripe_connect_id, stripe_onboarding_completed 
    INTO v_profile
    FROM profiles 
    WHERE id = p_user_id;

    IF v_profile.stripe_connect_id IS NULL OR v_profile.stripe_onboarding_completed IS NOT TRUE THEN
      RAISE EXCEPTION 'Cuenta de Stripe no vinculada o verificada';
    END IF;

    v_gateway := 'stripe';
    v_pm := NULL; -- Ensure v_pm is clear for automated flow
  ELSE
    -- Standard stored payment method
    SELECT *
    INTO v_pm
    FROM user_payment_methods
    WHERE id = p_payment_method_id::uuid AND user_id = p_user_id
    LIMIT 1;

    IF v_pm.id IS NULL THEN
      RAISE EXCEPTION 'Metodo de pago no encontrado';
    END IF;

    v_gateway := COALESCE(v_pm.type, 'pago_movil');
  END IF;

  IF NOT public.is_payment_method_enabled('withdrawal', v_gateway) THEN
    RAISE EXCEPTION 'Metodo de retiro deshabilitado: %', v_gateway;
  END IF;

  -- BCV rate only for pago_movil
  IF v_gateway = 'pago_movil' THEN
    SELECT (value)::numeric, updated_at
    INTO v_bcv_rate, v_rate_updated_at
    FROM app_config
    WHERE key = 'bcv_exchange_rate'
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_bcv_rate IS NULL OR v_bcv_rate <= 0 THEN
      RAISE EXCEPTION 'Tasa de cambio invalida';
    END IF;

    IF v_rate_updated_at IS NULL OR (now() - v_rate_updated_at) > interval '26 hours' THEN
      RAISE EXCEPTION 'Tasa de cambio desactualizada';
    END IF;

    v_amount_ves := v_plan.price * v_bcv_rate;
  ELSE
    v_bcv_rate := NULL;
    v_amount_ves := NULL;
  END IF;

  -- Verify balance again with row lock
  SELECT clovers
  INTO v_profile
  FROM profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_profile.clovers IS NULL OR v_profile.clovers < v_plan.amount THEN
    RAISE EXCEPTION 'Saldo insuficiente';
  END IF;

  UPDATE profiles
  SET clovers = clovers - v_plan.amount
  WHERE id = p_user_id AND clovers >= v_plan.amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Saldo insuficiente';
  END IF;

  INSERT INTO withdrawal_requests (
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
    CASE WHEN v_gateway = 'stripe' AND p_payment_method_id = 'stripe_connected_account' THEN NULL ELSE v_pm.id END,
    v_gateway,
    v_plan.amount,
    v_plan.price,
    v_amount_ves,
    v_bcv_rate,
    'pending',
    CASE 
      WHEN v_gateway = 'stripe' AND p_payment_method_id = 'stripe_connected_account' THEN 
           jsonb_build_object('automated', true, 'stripe_connect_id', (SELECT stripe_connect_id FROM profiles WHERE id = p_user_id))
      ELSE 
           jsonb_build_object(
             'bank_code', v_pm.bank_code,
             'dni', v_pm.dni,
             'phone_number', v_pm.phone_number,
             'stripe_email', v_pm.identifier
           )
    END,
    now(),
    now()
  )
  RETURNING id INTO v_request_id;

  INSERT INTO wallet_ledger (user_id, amount, description, metadata)
  VALUES (
    p_user_id,
    -v_plan.amount,
    'Retiro pendiente: ' || v_plan.name,
    jsonb_build_object(
      'type', 'withdrawal',
      'status', 'pending',
      'request_id', v_request_id::text,
      'plan_id', v_plan.id,
      'plan_name', v_plan.name,
      'gateway', v_gateway,
      'clovers_cost', v_plan.amount,
      'amount_usd', v_plan.price,
      'amount_ves', v_amount_ves,
      'bcv_rate', v_bcv_rate
    )
  );

  RETURN jsonb_build_object(
    'request_id', v_request_id,
    'gateway', v_gateway,
    'amount_usd', v_plan.price,
    'amount_ves', v_amount_ves,
    'clovers_cost', v_plan.amount,
    'bank_code', CASE WHEN v_pm IS NOT NULL THEN v_pm.bank_code ELSE NULL END,
    'dni', CASE WHEN v_pm IS NOT NULL THEN v_pm.dni ELSE NULL END,
    'phone_number', CASE WHEN v_pm IS NOT NULL THEN v_pm.phone_number ELSE NULL END,
    'stripe_email', CASE WHEN v_pm IS NOT NULL THEN v_pm.identifier ELSE NULL END
  );
END;
$$;

-- ------------------------------------------------------------
-- RPC: Mark withdrawal pending (provider latency)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_withdrawal_pending(
  p_request_id uuid,
  p_provider_data jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_req record;
BEGIN
  SELECT * INTO v_req
  FROM withdrawal_requests
  WHERE id = p_request_id
  LIMIT 1;

  IF v_req.id IS NULL THEN
    RAISE EXCEPTION 'Withdrawal request not found';
  END IF;

  UPDATE withdrawal_requests
  SET provider_data = COALESCE(provider_data, '{}'::jsonb) || COALESCE(p_provider_data, '{}'::jsonb),
      updated_at = now()
  WHERE id = p_request_id;

  IF NOT EXISTS (SELECT 1 FROM payment_transactions WHERE order_id = p_request_id::text) THEN
    INSERT INTO payment_transactions (user_id, order_id, amount, currency, status, provider_data, type)
    VALUES (v_req.user_id, p_request_id::text, v_req.amount_usd, 'USD', 'pending', p_provider_data, 'WITHDRAWAL');
  END IF;
END;
$$;

-- ------------------------------------------------------------
-- RPC: Mark withdrawal completed
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_withdrawal_completed(
  p_request_id uuid,
  p_provider_data jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_req record;
BEGIN
  SELECT * INTO v_req
  FROM withdrawal_requests
  WHERE id = p_request_id AND status = 'pending'
  FOR UPDATE;

  IF v_req.id IS NULL THEN
    RETURN;
  END IF;

  UPDATE withdrawal_requests
  SET status = 'completed',
      provider_data = COALESCE(provider_data, '{}'::jsonb) || COALESCE(p_provider_data, '{}'::jsonb),
      updated_at = now()
  WHERE id = p_request_id;

  IF NOT EXISTS (SELECT 1 FROM payment_transactions WHERE order_id = p_request_id::text) THEN
    INSERT INTO payment_transactions (user_id, order_id, amount, currency, status, provider_data, type)
    VALUES (v_req.user_id, p_request_id::text, v_req.amount_usd, 'USD', 'completed', p_provider_data, 'WITHDRAWAL');
  ELSE
    UPDATE payment_transactions
    SET status = 'completed', updated_at = now()
    WHERE order_id = p_request_id::text;
  END IF;

  UPDATE wallet_ledger
  SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{status}', '"completed"', true)
  WHERE user_id = v_req.user_id AND (metadata->>'request_id') = p_request_id::text;
END;
$$;

-- ------------------------------------------------------------
-- RPC: Mark withdrawal failed and optionally refund
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_withdrawal_failed(
  p_request_id uuid,
  p_provider_data jsonb,
  p_refund boolean DEFAULT true
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_req record;
BEGIN
  SELECT * INTO v_req
  FROM withdrawal_requests
  WHERE id = p_request_id AND status = 'pending'
  FOR UPDATE;

  IF v_req.id IS NULL THEN
    RETURN;
  END IF;

  UPDATE withdrawal_requests
  SET status = 'failed',
      provider_data = COALESCE(provider_data, '{}'::jsonb) || COALESCE(p_provider_data, '{}'::jsonb),
      updated_at = now()
  WHERE id = p_request_id;

  IF p_refund THEN
    UPDATE profiles
    SET clovers = clovers + v_req.clovers_cost
    WHERE id = v_req.user_id;

    INSERT INTO wallet_ledger (user_id, amount, description, metadata)
    VALUES (
      v_req.user_id,
      v_req.clovers_cost,
      'Reembolso por fallo en retiro',
      jsonb_build_object(
        'type', 'withdrawal_refund',
        'request_id', p_request_id::text,
        'plan_id', v_req.plan_id,
        'gateway', v_req.gateway
      )
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM payment_transactions WHERE order_id = p_request_id::text) THEN
    INSERT INTO payment_transactions (user_id, order_id, amount, currency, status, provider_data, type)
    VALUES (v_req.user_id, p_request_id::text, v_req.amount_usd, 'USD', 'failed', p_provider_data, 'WITHDRAWAL');
  ELSE
    UPDATE payment_transactions
    SET status = 'failed', updated_at = now()
    WHERE order_id = p_request_id::text;
  END IF;

  UPDATE wallet_ledger
  SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{status}', '"failed"', true)
  WHERE user_id = v_req.user_id AND (metadata->>'request_id') = p_request_id::text;
END;
$$;

-- Fix for create_withdrawal_request RPC signature mismatch
-- Adds DEFAULT NULL to p_payment_method_id to allow calls with only 2 parameters or explicit nulls

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

  -- If payment_method_id is provided, use it. Otherwise, look for default.
  IF p_payment_method_id IS NOT NULL THEN
    SELECT *
    INTO v_pm
    FROM user_payment_methods
    WHERE id = p_payment_method_id AND user_id = p_user_id
    LIMIT 1;
  ELSE
    -- Legacy/Default fallback if no method selected
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
      RAISE EXCEPTION 'Tasa de cambio BCV no disponible';
    END IF;

    v_amount_ves := v_plan.price * v_bcv_rate;
  ELSE
    v_bcv_rate := NULL;
    v_amount_ves := NULL;
  END IF;

  -- 2. DEDUCT CLOVERS (Atomic)
  UPDATE profiles
  SET clovers = clovers - v_plan.amount
  WHERE id = p_user_id AND clovers >= v_plan.amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Saldo insuficiente de tréboles';
  END IF;

  -- 3. CREATE REQUEST
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
    'bank_code', v_pm.bank_code,
    'dni', v_pm.dni,
    'phone_number', v_pm.phone_number,
    'stripe_email', v_pm.identifier
  );
END;
$$;

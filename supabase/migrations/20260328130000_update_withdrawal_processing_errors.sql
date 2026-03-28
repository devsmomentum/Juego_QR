-- Migration: Improved error handling for withdrawal processing
-- Updates mark_withdrawal_completed and mark_withdrawal_failed with explicit RAISE EXCEPTION calls.

CREATE OR REPLACE FUNCTION public.mark_withdrawal_completed(
  p_request_id uuid,
  p_provider_data jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_req record;
  v_stripe_email text;
BEGIN
  -- 1. Fetch request with row-level lock
  SELECT * INTO v_req
  FROM public.withdrawal_requests
  WHERE id = p_request_id
  FOR UPDATE;

  -- 2. Validation: Existence
  IF v_req.id IS NULL THEN
    RAISE EXCEPTION 'Solicitud de retiro no encontrada';
  END IF;

  -- 3. Validation: Status
  IF v_req.status != 'pending' THEN
    RAISE EXCEPTION 'Solo se pueden completar solicitudes en estado "pending" (Estado actual: %)', v_req.status;
  END IF;

  -- 4. Validation: Provider Data (Stripe Case)
  IF v_req.gateway = 'stripe' THEN
    v_stripe_email := (v_req.provider_data ->> 'stripe_email');
    IF v_stripe_email IS NULL OR v_stripe_email = '' THEN
      RAISE EXCEPTION 'No se encontro un correo de Stripe para realizar la referencia del pago';
    END IF;
  END IF;

  -- 5. PERFORM UPDATES (Same as before but safer)
  UPDATE public.withdrawal_requests
  SET 
    status = 'completed',
    provider_data = COALESCE(provider_data, '{}'::jsonb) || COALESCE(p_provider_data, '{}'::jsonb),
    updated_at = now()
  WHERE id = p_request_id;

  -- Update payment_transactions
  IF NOT EXISTS (SELECT 1 FROM public.payment_transactions WHERE order_id = p_request_id::text) THEN
    INSERT INTO public.payment_transactions (user_id, order_id, amount, currency, status, provider_data, type)
    VALUES (v_req.user_id, p_request_id::text, v_req.amount_usd, 'USD', 'completed', p_provider_data, 'WITHDRAWAL');
  ELSE
    UPDATE public.payment_transactions
    SET status = 'completed', updated_at = now()
    WHERE order_id = p_request_id::text;
  END IF;

  -- Update wallet_ledger
  UPDATE public.wallet_ledger
  SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{status}', '"completed"', true)
  WHERE user_id = v_req.user_id AND (metadata->>'request_id') = p_request_id::text;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Retiro completado exitosamente'
  );
END;
$$;


CREATE OR REPLACE FUNCTION public.mark_withdrawal_failed(
  p_request_id uuid,
  p_provider_data jsonb,
  p_refund boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_req record;
BEGIN
  -- 1. Fetch request with row-level lock
  SELECT * INTO v_req
  FROM public.withdrawal_requests
  WHERE id = p_request_id
  FOR UPDATE;

  -- 2. Validation: Existence
  IF v_req.id IS NULL THEN
    RAISE EXCEPTION 'Solicitud de retiro no encontrada';
  END IF;

  -- 3. Validation: Status
  IF v_req.status != 'pending' THEN
    RAISE EXCEPTION 'Solo se pueden rechazar solicitudes en estado "pending" (Estado actual: %)', v_req.status;
  END IF;

  -- 4. PERFORM REJECTION
  UPDATE public.withdrawal_requests
  SET 
    status = 'failed',
    provider_data = COALESCE(provider_data, '{}'::jsonb) || COALESCE(p_provider_data, '{}'::jsonb),
    updated_at = now()
  WHERE id = p_request_id;

  -- 5. REFUND IF APPLICABLE
  IF p_refund THEN
    UPDATE public.profiles
    SET clovers = clovers + v_req.clovers_cost
    WHERE id = v_req.user_id;

    INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
    VALUES (
      v_req.user_id,
      v_req.clovers_cost,
      'Reembolso por rechazo de retiro',
      jsonb_build_object(
        'type', 'withdrawal_refund',
        'request_id', p_request_id::text,
        'plan_id', v_req.plan_id,
        'gateway', v_req.gateway
      )
    );
  END IF;

  -- 6. SYNC TRANSACTIONS/LEDGER
  IF NOT EXISTS (SELECT 1 FROM public.payment_transactions WHERE order_id = p_request_id::text) THEN
    INSERT INTO public.payment_transactions (user_id, order_id, amount, currency, status, provider_data, type)
    VALUES (v_req.user_id, p_request_id::text, v_req.amount_usd, 'USD', 'failed', p_provider_data, 'WITHDRAWAL');
  ELSE
    UPDATE public.payment_transactions
    SET status = 'failed', updated_at = now()
    WHERE order_id = p_request_id::text;
  END IF;

  UPDATE public.wallet_ledger
  SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{status}', '"failed"', true)
  WHERE user_id = v_req.user_id AND (metadata->>'request_id') = p_request_id::text;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Retiro rechazado ' || CASE WHEN p_refund THEN 'y reembolsado ' ELSE '' END || 'exitosamente'
  );
END;
$$;

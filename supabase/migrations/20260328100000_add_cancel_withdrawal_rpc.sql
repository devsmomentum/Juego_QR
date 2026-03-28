-- SQL Migration: Add cancel_withdrawal_request RPC
-- Allows a user to cancel their own withdrawal request if it is still pending.

CREATE OR REPLACE FUNCTION public.cancel_withdrawal_request(
  p_request_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_request record;
BEGIN
  -- 1. Get the request (ensuring ownership)
  SELECT * INTO v_request
  FROM public.withdrawal_requests
  WHERE id = p_request_id;

  IF v_request.id IS NULL THEN
    RAISE EXCEPTION 'Solicitud no encontrada';
  END IF;

  -- 2. Authorization check
  IF (auth.uid() != v_request.user_id) AND (auth.role() != 'service_role') THEN
    RAISE EXCEPTION 'No tienes permiso para cancelar esta solicitud';
  END IF;

  -- 3. Check current status
  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Solo se pueden cancelar solicitudes pendientes (Estado actual: %)', v_request.status;
  END IF;

  -- 4. Mark as failed/cancelled
  UPDATE public.withdrawal_requests
  SET 
    status = 'failed',
    provider_data = provider_data || jsonb_build_object(
      'cancellation_reason', 'Cancelado por el usuario',
      'cancelled_at', now()
    ),
    updated_at = now()
  WHERE id = p_request_id;

  -- 5. Refund Clovers to profile
  UPDATE public.profiles
  SET clovers = clovers + v_request.clovers_cost
  WHERE id = v_request.user_id;

  -- 6. Add Ledger Entry for refund
  INSERT INTO wallet_ledger (user_id, amount, description, metadata)
  VALUES (
    v_request.user_id,
    v_request.clovers_cost,
    'Reembolso por retiro cancelado',
    jsonb_build_object(
      'type', 'withdrawal_refund',
      'request_id', p_request_id::text,
      'original_amount_usd', v_request.amount_usd
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Solicitud cancelada y tréboles devueltos'
  );
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.cancel_withdrawal_request(uuid) TO authenticated;

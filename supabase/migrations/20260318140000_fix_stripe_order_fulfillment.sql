-- ============================================================
-- Migration: Fix Stripe Order Fulfillment & Add Admin Support
-- Created: 2026-03-18
-- Descripción: Corrige el trigger de fulfillment para manejar
--              pedidos de Stripe (stripe_payment_intent_id) además
--              de Pago a Pago (pago_pago_order_id). También añade
--              una política RLS para que admins vean todas las órdenes.
-- ============================================================

-- 1. CORREGIR trigger function para manejar gateway 'stripe' vs 'pago_movil'
CREATE OR REPLACE FUNCTION public.process_paid_clover_order()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    treboles_comprados numeric;
    order_ref          text;
BEGIN
    -- 1. Solo ejecutar cuando el status cambia a 'success'
    IF (NEW.status = 'success' AND OLD.status IS DISTINCT FROM 'success') THEN

        -- 2. Extraer la cantidad desde extra_data
        treboles_comprados := (NEW.extra_data->>'clovers_amount')::numeric;

        -- 3. Validación de seguridad
        IF treboles_comprados IS NULL OR treboles_comprados <= 0 THEN
            RAISE EXCEPTION '[process_paid_clover_order] clovers_amount inválido en extra_data para order_id=%', NEW.id;
        END IF;

        -- 4. Construir referencia legible según el gateway usado
        IF NEW.gateway = 'stripe' AND NEW.stripe_payment_intent_id IS NOT NULL THEN
            order_ref := NEW.stripe_payment_intent_id;
        ELSIF NEW.pago_pago_order_id IS NOT NULL THEN
            order_ref := NEW.pago_pago_order_id;
        ELSE
            order_ref := NEW.id::text;
        END IF;

        -- 5. Acreditar tréboles en el perfil del usuario
        UPDATE public.profiles
        SET clovers = COALESCE(clovers, 0) + treboles_comprados
        WHERE id = NEW.user_id;

        -- 6. Registrar en el Ledger de auditoría
        INSERT INTO public.wallet_ledger (user_id, order_id, amount, description)
        VALUES (
            NEW.user_id,
            NEW.id,
            treboles_comprados,
            'Compra de tréboles [' || UPPER(COALESCE(NEW.gateway, 'unknown')) || '] - Ref: ' || order_ref
        );

    END IF;

    RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.process_paid_clover_order() IS
'Trigger AFTER UPDATE on clover_orders. Acredita tréboles al usuario
 cuando status cambia a success. Soporta gateway stripe y pago_movil.';

-- 2. POLÍTICA RLS: Administradores pueden ver TODAS las órdenes de tréboles
DO $$
BEGIN
  -- Eliminar si ya existe para evitar conflicto
  DROP POLICY IF EXISTS "Admins can view all clover_orders" ON public.clover_orders;

  CREATE POLICY "Admins can view all clover_orders"
  ON public.clover_orders
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'user_staff')
    )
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Could not create RLS policy for clover_orders: %', SQLERRM;
END $$;

-- 3. ÍNDICE: Búsqueda rápida por gateway para reportes de admin
CREATE INDEX IF NOT EXISTS idx_clover_orders_gateway_status
  ON public.clover_orders (gateway, status, created_at DESC);

-- 4. VISTA ADMIN: Vista enriquecida de órdenes Stripe para el panel de administración
CREATE OR REPLACE VIEW public.admin_stripe_orders AS
SELECT
  co.id,
  co.user_id,
  p.name         AS user_name,
  p.email        AS user_email,
  co.gateway,
  co.status,
  co.amount,
  co.currency,
  co.stripe_payment_intent_id,
  co.pago_pago_order_id,
  (co.extra_data->>'clovers_amount')::numeric AS clovers_amount,
  (co.extra_data->>'plan_name')::text          AS plan_name,
  co.created_at,
  co.updated_at,
  co.expires_at
FROM public.clover_orders co
LEFT JOIN public.profiles p ON p.id = co.user_id
ORDER BY co.created_at DESC;

COMMENT ON VIEW public.admin_stripe_orders IS
'Vista enriquecida para el panel de admin. Muestra todas las órdenes
 con datos del usuario, gateway y estado.';

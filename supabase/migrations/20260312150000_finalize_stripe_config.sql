-- Migration: Final Stripe DB Setup (FIXED)
-- Fecha: 2026-03-12
-- Descripción: Ajustes mínimos para habilitar Stripe. Incluye creación de columnas si no existen.

-- 1. Crear columnas necesarias si no existen
ALTER TABLE public.clover_orders 
  ADD COLUMN IF NOT EXISTS gateway TEXT NOT NULL DEFAULT 'pago_movil',
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT;

-- 2. Index para búsquedas ultra-rápidas por ID de Stripe
CREATE INDEX IF NOT EXISTS idx_clover_orders_stripe_pi
  ON public.clover_orders (stripe_payment_intent_id)
  WHERE stripe_payment_intent_id IS NOT NULL;

-- 3. Asegurar que la columna 'gateway' acepte el valor 'stripe'
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='clover_orders' AND column_name='gateway') THEN
    ALTER TABLE public.clover_orders DROP CONSTRAINT IF EXISTS chk_clover_orders_gateway;
    ALTER TABLE public.clover_orders ADD CONSTRAINT chk_clover_orders_gateway 
      CHECK (gateway IN ('pago_movil', 'stripe', 'internal'));
  END IF;
END $$;

COMMENT ON COLUMN public.clover_orders.gateway IS 'Proveedor de pago: pago_movil, stripe, o internal';
COMMENT ON COLUMN public.clover_orders.stripe_payment_intent_id IS 'ID del PaymentIntent de Stripe (pi_xxxx)';

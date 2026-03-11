-- Migration: Add Stripe gateway support to clover_orders
-- Created: 2026-03-11

-- Add gateway column to track which payment provider was used
ALTER TABLE clover_orders
  ADD COLUMN IF NOT EXISTS gateway TEXT NOT NULL DEFAULT 'pago_movil';

-- Add Stripe-specific payment intent ID column
ALTER TABLE clover_orders
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT;

-- Index for fast lookups by Stripe payment intent
CREATE INDEX IF NOT EXISTS idx_clover_orders_stripe_pi
  ON clover_orders (stripe_payment_intent_id)
  WHERE stripe_payment_intent_id IS NOT NULL;

-- Add check constraint to validate gateway values
ALTER TABLE clover_orders
  ADD CONSTRAINT chk_clover_orders_gateway
  CHECK (gateway IN ('pago_movil', 'stripe', 'internal'));

COMMENT ON COLUMN clover_orders.gateway IS 'Payment gateway used: pago_movil, stripe, or internal';
COMMENT ON COLUMN clover_orders.stripe_payment_intent_id IS 'Stripe PaymentIntent ID (pi_xxx) for Stripe orders';

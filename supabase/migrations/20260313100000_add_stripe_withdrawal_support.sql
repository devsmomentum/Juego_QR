-- Migration: Add Stripe withdrawal support to user_payment_methods
-- Created at: 2026-03-13

-- Add type column to distinguish between pago_movil and stripe
ALTER TABLE "public"."user_payment_methods" 
ADD COLUMN IF NOT EXISTS "type" TEXT NOT NULL DEFAULT 'pago_movil';

-- Add identifier column for Stripe email or other identifiers
ALTER TABLE "public"."user_payment_methods" 
ADD COLUMN IF NOT EXISTS "identifier" TEXT;

-- Update existing rows to ensure they have the correct type
UPDATE "public"."user_payment_methods" SET "type" = 'pago_movil' WHERE "type" IS NULL;

-- Add a check constraint for type
ALTER TABLE "public"."user_payment_methods"
DROP CONSTRAINT IF EXISTS "user_payment_methods_type_check",
ADD CONSTRAINT "user_payment_methods_type_check" CHECK ("type" IN ('pago_movil', 'stripe'));

-- Optional: Add a comment to the columns
COMMENT ON COLUMN "public"."user_payment_methods"."type" IS 'Type of payment method: pago_movil or stripe';
COMMENT ON COLUMN "public"."user_payment_methods"."identifier" IS 'Email address for Stripe or other unique identifier for the method';

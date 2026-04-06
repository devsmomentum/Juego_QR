-- Migration: Add stripe_customer_id to profiles for card saving feature
-- Date: 2026-03-26

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT;

COMMENT ON COLUMN public.profiles.stripe_customer_id IS 'Stripe Customer ID (cus_xxx) — allows reusing saved payment methods across purchases';

CREATE INDEX IF NOT EXISTS idx_profiles_stripe_customer_id
  ON public.profiles (stripe_customer_id)
  WHERE stripe_customer_id IS NOT NULL;

-- ============================================================
-- Migration: Add validation_code to clover_orders + Create mpay_validations table
-- Purpose: Support manual Pago Móvil validation flow
-- ============================================================

-- 1. Add validation_code column to clover_orders
ALTER TABLE public.clover_orders
  ADD COLUMN IF NOT EXISTS validation_code TEXT UNIQUE;

-- Index for fast lookup by validation_code
CREATE INDEX IF NOT EXISTS idx_clover_orders_validation_code
  ON public.clover_orders (validation_code)
  WHERE validation_code IS NOT NULL;

-- 2. Create mpay_validations audit table
CREATE TABLE IF NOT EXISTS public.mpay_validations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES public.clover_orders(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  reference TEXT NOT NULL,
  concept TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed')),
  amount_raw NUMERIC(15,2),
  fee_bank NUMERIC(15,2),         -- 1.5% banco
  fee_platform NUMERIC(15,2),     -- 0.5% plataforma
  amount_user NUMERIC(15,2),      -- 98% usuario
  api_response JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookup by order
CREATE INDEX IF NOT EXISTS idx_mpay_validations_order_id
  ON public.mpay_validations (order_id);

-- Index for fast lookup by user
CREATE INDEX IF NOT EXISTS idx_mpay_validations_user_id
  ON public.mpay_validations (user_id);

-- 3. RLS policies for mpay_validations
ALTER TABLE public.mpay_validations ENABLE ROW LEVEL SECURITY;

-- Users can only read their own validation records
CREATE POLICY "users_select_own_mpay_validations"
  ON public.mpay_validations
  FOR SELECT
  USING (auth.uid() = user_id);

-- Only service role (Edge Functions) can insert/update
-- (no INSERT/UPDATE policy for authenticated users)

-- 4. Function to generate a short alphanumeric validation code
CREATE OR REPLACE FUNCTION public.generate_validation_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  code TEXT;
  attempts INT := 0;
BEGIN
  LOOP
    -- Generate 8-char alphanumeric code (uppercase)
    code := upper(substr(md5(gen_random_uuid()::text), 1, 8));
    
    -- Check uniqueness
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.clover_orders WHERE validation_code = code
    );
    
    attempts := attempts + 1;
    IF attempts > 10 THEN
      RAISE EXCEPTION 'Could not generate unique validation code after 10 attempts';
    END IF;
  END LOOP;
  
  RETURN code;
END;
$$;

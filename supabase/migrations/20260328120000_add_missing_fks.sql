-- Migration: Add missing Foreign Key for withdrawal_requests to profiles
-- This fixes the 'PostgrestException: Could not find a relationship' error in Admin Dashboard.

-- 1. Ensure the user_id column in withdrawal_requests is a foreign key to profiles.id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'withdrawal_requests_user_id_fkey'
    ) THEN
        ALTER TABLE "public"."withdrawal_requests" 
        ADD CONSTRAINT "withdrawal_requests_user_id_fkey" 
        FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") 
        ON DELETE CASCADE;
    END IF;
END $$;

-- 2. Ensure the plan_id column also has a foreign key if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'withdrawal_requests_plan_id_fkey'
    ) THEN
        ALTER TABLE "public"."withdrawal_requests" 
        ADD CONSTRAINT "withdrawal_requests_plan_id_fkey" 
        FOREIGN KEY ("plan_id") REFERENCES "public"."transaction_plans"("id") 
        ON DELETE CASCADE;
    END IF;
END $$;

-- 3. Trigger a schema cache reload for PostgREST
NOTIFY pgrst, 'reload schema';
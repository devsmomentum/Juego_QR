-- =============================================================================
-- EXPIRE PENDING ORDERS CRON JOB
-- =============================================================================
-- Runs every minute. If a pending order's expires_at has passed, mark it expired.
-- PAP handles expiration on their side independently.
-- =============================================================================

-- 1. Remove old cron jobs if they exist
SELECT cron.unschedule('expire_old_orders')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire_old_orders');

SELECT cron.unschedule('expire_stale_orders')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire_stale_orders');

-- 2. Schedule job every minute
SELECT cron.schedule(
  'expire_stale_orders',
  '* * * * *',
  $$
    UPDATE public.clover_orders
    SET status = 'expired', updated_at = now()
    WHERE status = 'pending'
      AND expires_at < now();
  $$
);

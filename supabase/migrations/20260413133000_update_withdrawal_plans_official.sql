-- Migration: Official Withdrawal Plans (3-tier)
-- Reset and establish the 3 official plans for withdrawals.

-- 1. Clean existing withdrawal plans to avoid confusion
DELETE FROM public.transaction_plans WHERE type = 'withdraw';

-- 2. Insert new official plans
-- price is the NET amount the user receives in USD.
-- amount is the cost in clovers.
INSERT INTO public.transaction_plans (
    name, 
    amount, 
    price, 
    type, 
    is_active, 
    sort_order,
    icon_url
) VALUES 
('Bronce ($10 Netos)', 575, 10.00, 'withdraw', true, 1, '🥉'),
('Plata ($25 Netos)', 1375, 25.00, 'withdraw', true, 2, '🥈'),
('Oro ($50 Netos)', 2675, 50.00, 'withdraw', true, 3, '🥇');

-- 3. Update Global config to ensure PayPal and withdrawal features are visible
-- (This part might already exist, but ensuring consistency)
INSERT INTO public.app_config (key, value)
VALUES ('payment_methods_status', '{"withdrawal": {"paypal": true, "pago_movil": true, "stripe": true}}')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

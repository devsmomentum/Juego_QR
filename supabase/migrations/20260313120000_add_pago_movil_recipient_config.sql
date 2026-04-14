-- ============================================================
-- Migration: Seed pago_movil_recipient row in app_config
-- Purpose: Store Pago Móvil recipient data (banco, cedula, telefono)
--          that is shown to users during the payment validation flow.
-- ============================================================

INSERT INTO public.app_config (key, value, updated_at)
VALUES (
  'pago_movil_recipient',
  '{"banco": "", "cedula": "", "telefono": ""}'::jsonb,
  now()
)
ON CONFLICT (key) DO NOTHING;
